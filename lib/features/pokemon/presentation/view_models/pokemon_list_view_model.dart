import 'dart:async';

import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';
import 'package:pokedex/features/pokemon/presentation/state/pokemon_list_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pokemon_list_view_model.g.dart';

/// MVVM ViewModel for the Home list (Tech Spec §5.2).
///
/// Owns the single [PokemonListState] for the Home screen and routes every
/// intent through one of two modes:
///
/// - **Browse** — all defaults: paginated `getPokemonList` page fetches feed
///   the cache, and a `watchPokemonList` stream re-syncs `items` whenever the
///   cache changes (so background revalidations surface to the UI without a
///   manual refresh).
/// - **Discovery** — any non-default axis (search, filter, sort, generation):
///   the stream is cancelled and `findPokemon` runs against the cache.
///
/// Pull-to-refresh always asks the network: in discovery, the page fetch
/// repopulates the cache and `findPokemon` re-runs over the freshened cache
/// (resolved blocker 2).
@riverpod
class PokemonListViewModel extends _$PokemonListViewModel {
  static const int _pageSize = 24;
  static const Duration _searchDebounce = Duration(milliseconds: 300);
  static const int _maxQueryLength = 50;

  Timer? _debounce;
  StreamSubscription<List<Pokemon>>? _streamSub;

  /// Monotonic guard that lets a slow-resolving discovery transition recognise
  /// that a newer transition has already overtaken it (so it skips its state
  /// update). Incremented on entry to every `_enterDiscovery` call.
  int _discoverySeq = 0;

  @override
  Future<PokemonListState> build() async {
    // Disposal first — fires on rebuild AND on provider invalidation.
    ref.onDispose(() {
      _debounce?.cancel();
      _streamSub?.cancel().ignore();
    });

    final initial = await _loadFirstPage();
    _subscribeBrowseStream(sort: SortCriteria.numberAsc);
    return initial;
  }

  /// UC-01: appends the next page when scrolled to the end.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore || current.isDiscovery) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    final result = await ref
        .read(getPokemonListProvider)
        .call(limit: _pageSize, offset: current.offset);
    final after = state.value;
    if (after == null) return;
    switch (result) {
      case Ok(:final value):
        final merged = <Pokemon>[...after.items, ...value.items];
        state = AsyncData(
          after.copyWith(
            items: merged,
            offset: merged.length,
            hasMore: value.hasMore,
            isLoadingMore: false,
          ),
        );
      case Err():
        // No dedicated loadMore-error field in the state shape; swallow so the
        // existing items stay readable and a subsequent refresh can recover.
        state = AsyncData(after.copyWith(isLoadingMore: false));
    }
  }

  /// UC-02: debounces 300ms (RF-10) then transitions the discovery axis.
  ///
  /// The query field is updated synchronously so the search input feels
  /// responsive; only the mode transition is debounced.
  void search(String query) {
    final current = state.value;
    if (current == null) return;
    final trimmed = query.trim();
    final capped = trimmed.length > _maxQueryLength
        ? trimmed.substring(0, _maxQueryLength)
        : trimmed;
    state = AsyncData(current.copyWith(query: capped));
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _applyMode);
  }

  /// UC-03: applies (or clears, with `null`) the filter and re-evaluates mode.
  void applyFilter(PokemonFilter? filter) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(filter: filter));
    _applyMode();
  }

  /// UC-04: switches sort criterion and re-evaluates mode.
  void changeSort(SortCriteria sort) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(sort: sort));
    _applyMode();
  }

  /// UC-05: picks (or clears, with `null`) the active generation.
  void selectGeneration(int? id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(generationId: id));
    _applyMode();
  }

  /// UC-08: pull-to-refresh.
  ///
  /// In browse, replaces page 0 from the network. In discovery, asks the
  /// network first (to repopulate the cache) then re-runs the discovery query
  /// over the freshened cache (resolved blocker 2).
  Future<void> refresh() async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(isRefreshing: true, refreshError: null),
    );

    final pageResult = await ref
        .read(getPokemonListProvider)
        .call(limit: _pageSize, offset: 0);

    final after = state.value;
    if (after == null) return;

    if (after.isDiscovery) {
      // Carry forward a page-level failure as the refresh banner; still re-run
      // findPokemon so the user sees filtered cache (possibly stale).
      final pageFailure = switch (pageResult) {
        Err(:final failure) => failure,
        Ok() => null,
      };
      final findResult = await ref
          .read(findPokemonProvider)
          .call(
            sort: after.sort,
            query: after.query.isEmpty ? null : after.query,
            filter: _composeFilter(after),
          );
      final next = state.value;
      if (next == null) return;
      switch (findResult) {
        case Ok(:final value):
          state = AsyncData(
            next.copyWith(
              items: value,
              offset: value.length,
              hasMore: false,
              isRefreshing: false,
              refreshError: pageFailure,
            ),
          );
        case Err(:final failure):
          state = AsyncData(
            next.copyWith(isRefreshing: false, refreshError: failure),
          );
      }
      return;
    }

    switch (pageResult) {
      case Ok(:final value):
        state = AsyncData(
          after.copyWith(
            items: value.items,
            offset: value.items.length,
            hasMore: value.hasMore,
            isRefreshing: false,
          ),
        );
      case Err(:final failure):
        state = AsyncData(
          after.copyWith(isRefreshing: false, refreshError: failure),
        );
    }
  }

  Future<PokemonListState> _loadFirstPage() async {
    final result = await ref
        .read(getPokemonListProvider)
        .call(limit: _pageSize, offset: 0);
    return switch (result) {
      Ok(:final value) => PokemonListState(
        items: value.items,
        offset: value.items.length,
        hasMore: value.hasMore,
      ),
      Err(:final failure) => throw failure,
    };
  }

  void _subscribeBrowseStream({required SortCriteria sort}) {
    _streamSub?.cancel().ignore();
    _streamSub = ref.read(watchPokemonListProvider).call(sort: sort).listen((
      items,
    ) {
      final current = state.value;
      if (current == null || current.isDiscovery) return;
      state = AsyncData(
        current.copyWith(items: items, offset: items.length),
      );
    });
  }

  void _applyMode() {
    final current = state.value;
    if (current == null) return;
    if (current.isDiscovery) {
      unawaited(_enterDiscovery());
    } else {
      _enterBrowse();
    }
  }

  Future<void> _enterDiscovery() async {
    _streamSub?.cancel().ignore();
    _streamSub = null;
    final current = state.value;
    if (current == null) return;
    // Tag this invocation so a newer one can supersede it on resolve.
    final seq = ++_discoverySeq;
    // Preserve UI inputs (query/filter/sort/generationId) during the flip so
    // the search field and chips never flash empty (resolved blocker 1).
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<PokemonListState>().copyWithPrevious(state);
    final result = await ref
        .read(findPokemonProvider)
        .call(
          sort: current.sort,
          query: current.query.isEmpty ? null : current.query,
          filter: _composeFilter(current),
        );
    // A newer discovery transition has already mutated state — drop this
    // resolve so its stale snapshot can't overwrite the fresher result.
    if (seq != _discoverySeq) return;
    final latest = state.value ?? current;
    switch (result) {
      case Ok(:final value):
        state = AsyncData(
          latest.copyWith(
            items: value,
            offset: value.length,
            hasMore: false,
            isLoadingMore: false,
            isRefreshing: false,
          ),
        );
      case Err(:final failure):
        final error = AsyncError<PokemonListState>(
          failure,
          StackTrace.current,
        );
        // Preserve UI inputs on the error path (resolved blocker 1).
        // ignore: invalid_use_of_internal_member
        state = error.copyWithPrevious(state);
    }
  }

  void _enterBrowse() {
    final current = state.value;
    if (current == null) return;
    _subscribeBrowseStream(sort: current.sort);
  }

  /// Merges the explicit [PokemonListState.filter] with the orthogonal
  /// generation selection (PR1 groundwork) into a single wire-shape filter.
  PokemonFilter? _composeFilter(PokemonListState state) {
    if (state.filter == null && state.generationId == null) return null;
    final base = state.filter ?? const PokemonFilter();
    return base.copyWith(generationId: state.generationId);
  }
}
