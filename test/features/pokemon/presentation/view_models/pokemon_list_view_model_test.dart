import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/core/observability/observability_providers.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';
import 'package:pokedex/features/pokemon/presentation/state/pokemon_list_state.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_list_view_model.dart';

import '../../../../helpers/recording_observability.dart';

class _MockGetPokemonList extends Mock implements GetPokemonList {}

class _MockFindPokemon extends Mock implements FindPokemon {}

class _MockWatchPokemonList extends Mock implements WatchPokemonList {}

class _MockRepository extends Mock implements PokemonRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

// Slightly over the VM's 300 ms debounce — keeps the test responsive while
// still letting the timer fire.
const _overDebounce = Duration(milliseconds: 320);

Pokemon _pokemon(int id, {String name = 'pkmn', int gen = 1}) => Pokemon(
  id: id,
  name: name,
  imageUrl: 'https://img/$id.png',
  generationId: gen,
  types: const [PokemonTypeId.grass],
);

List<Pokemon> _page(int start, int count, {int gen = 1}) => [
  for (var i = 0; i < count; i++) _pokemon(start + i, gen: gen),
];

void main() {
  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
    registerFallbackValue(const PokemonFilter());
  });

  late _MockGetPokemonList getList;
  late _MockFindPokemon findPokemon;
  late _MockWatchPokemonList watchList;
  late _MockRepository repository;
  late _MockConnectivity connectivity;
  late StreamController<List<Pokemon>> cacheController;
  late RecordingAnalytics analytics;
  late RecordingErrorReporter reporter;
  late ProviderContainer container;

  PokemonListState valueOrThrow(ProviderContainer c) {
    final value = c.read(pokemonListViewModelProvider).value;
    if (value == null) {
      throw StateError(
        'PokemonListViewModel state has no value: '
        '${c.read(pokemonListViewModelProvider)}',
      );
    }
    return value;
  }

  setUp(() {
    getList = _MockGetPokemonList();
    findPokemon = _MockFindPokemon();
    watchList = _MockWatchPokemonList();
    repository = _MockRepository();
    connectivity = _MockConnectivity();
    cacheController = StreamController<List<Pokemon>>.broadcast();
    analytics = RecordingAnalytics();
    reporter = RecordingErrorReporter();

    when(
      () => getList.call(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => Ok(PokemonPage(items: _page(1, 24), hasMore: true)),
    );

    when(
      () => watchList.call(
        sort: any(named: 'sort'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => cacheController.stream);

    when(
      () => findPokemon.call(
        sort: any(named: 'sort'),
        query: any(named: 'query'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => Ok(_page(100, 3)));

    // Catalogue-coverage providers (IndexCoordinator / BackfillCoordinator)
    // are stateless side-effects from the ViewModel's perspective; stub the
    // shared repository + connectivity so the kickoff coroutine no-ops without
    // surfacing errors.
    when(repository.readIndexState).thenAnswer((_) async => IndexState.idle());
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => connectivity.onConnectivityChanged).thenAnswer(
      (_) => const Stream<List<ConnectivityResult>>.empty(),
    );

    container = ProviderContainer(
      overrides: [
        getPokemonListProvider.overrideWithValue(getList),
        findPokemonProvider.overrideWithValue(findPokemon),
        watchPokemonListProvider.overrideWithValue(watchList),
        pokemonRepositoryProvider.overrideWithValue(repository),
        connectivityProvider.overrideWithValue(connectivity),
        analyticsServiceProvider.overrideWithValue(analytics),
        errorReporterProvider.overrideWithValue(reporter),
      ],
    );
  });

  /// Builds the VM and keeps a listener alive so auto-dispose doesn't tear the
  /// notifier down between subsequent reads. Tests call this AFTER overriding
  /// any stubs specific to the test.
  Future<PokemonListState> pumpInitial() async {
    container.listen(pokemonListViewModelProvider, (_, _) {});
    return container.read(pokemonListViewModelProvider.future);
  }

  tearDown(() async {
    container.dispose();
    await cacheController.close();
  });

  group('PokemonListViewModel — browse', () {
    test('build() loads page 0 and sets initial browse state', () async {
      final state = await pumpInitial();

      expect(state.items.length, 24);
      expect(state.offset, 24);
      expect(state.hasMore, isTrue);
      expect(state.isDiscovery, isFalse);
      expect(cacheController.hasListener, isTrue);
      verify(() => getList.call(limit: 24, offset: 0)).called(1);
    });

    test('build() surfaces AsyncError when the first page fails', () async {
      when(
        () => getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      // Drive the future to completion; the exception is captured on the
      // AsyncValue rather than rethrown to the caller of .future.
      container.listen(pokemonListViewModelProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final async = container.read(pokemonListViewModelProvider);
      expect(async.hasError, isTrue);
      expect(async.error, isA<NetworkFailure>());
    });

    test('loadMore appends the next page and advances offset', () async {
      await pumpInitial();

      when(
        () => getList.call(limit: 24, offset: 24),
      ).thenAnswer(
        (_) async => Ok(PokemonPage(items: _page(25, 24), hasMore: false)),
      );

      await container.read(pokemonListViewModelProvider.notifier).loadMore();

      final state = valueOrThrow(container);
      expect(state.items.length, 48);
      expect(state.offset, 48);
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });

    test(
      'loadMore on Err keeps existing items and clears isLoadingMore',
      () async {
        await pumpInitial();

        when(
          () => getList.call(limit: 24, offset: 24),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        await container.read(pokemonListViewModelProvider.notifier).loadMore();

        final state = valueOrThrow(container);
        expect(state.items.length, 24);
        expect(state.offset, 24);
        expect(state.isLoadingMore, isFalse);
      },
    );

    test('loadMore is a no-op when hasMore is false', () async {
      when(
        () => getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => Ok(PokemonPage(items: _page(1, 24), hasMore: false)),
      );

      await pumpInitial();
      clearInteractions(getList);

      await container.read(pokemonListViewModelProvider.notifier).loadMore();

      verifyNever(
        () => getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );
    });

    test('stream emission replaces items and resyncs offset', () async {
      await pumpInitial();

      cacheController.add(_page(1, 30));
      await Future<void>.delayed(Duration.zero);

      final state = valueOrThrow(container);
      expect(state.items.length, 30);
      expect(state.offset, 30);
    });
  });

  group('PokemonListViewModel — discovery', () {
    test(
      'search enters discovery after debounce and calls findPokemon',
      () async {
        await pumpInitial();

        container.read(pokemonListViewModelProvider.notifier).search('pikachu');
        // Before debounce fires, query is set but the stream stays subscribed.
        expect(valueOrThrow(container).query, 'pikachu');
        expect(cacheController.hasListener, isTrue);

        await Future<void>.delayed(_overDebounce);
        // Pump microtasks so the discovery findPokemon resolves.
        await Future<void>.delayed(Duration.zero);

        final state = valueOrThrow(container);
        expect(state.isDiscovery, isTrue);
        expect(state.items.length, 3);
        expect(state.hasMore, isFalse);
        expect(cacheController.hasListener, isFalse);
        verify(
          () => findPokemon.call(
            sort: SortCriteria.numberAsc,
            query: 'pikachu',
          ),
        ).called(1);
      },
    );

    test('search trims and caps query at 50 chars', () async {
      await pumpInitial();

      final long = '   ${'a' * 80}   ';
      container.read(pokemonListViewModelProvider.notifier).search(long);

      expect(valueOrThrow(container).query.length, 50);
      expect(valueOrThrow(container).query, 'a' * 50);
    });

    test(
      'debounce coalesces rapid search calls into a single findPokemon',
      () async {
        await pumpInitial();

        container.read(pokemonListViewModelProvider.notifier)
          ..search('a')
          ..search('ab')
          ..search('abc')
          ..search('abcd');

        await Future<void>.delayed(_overDebounce);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => findPokemon.call(
            sort: SortCriteria.numberAsc,
            query: 'abcd',
          ),
        ).called(1);
      },
    );

    test(
      'AsyncLoading.copyWithPrevious preserves query/sort/filter during the flip',
      () async {
        await pumpInitial();

        // Make findPokemon hang so we can observe the in-flight AsyncLoading.
        final completer = Completer<Result<List<Pokemon>>>();
        when(
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) => completer.future);

        container
            .read(pokemonListViewModelProvider.notifier)
            .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));

        // applyFilter is synchronous (no debounce). Pump microtasks to let
        // _enterDiscovery's first await checkpoint run.
        await Future<void>.delayed(Duration.zero);

        final async = container.read(pokemonListViewModelProvider);
        expect(async.isLoading, isTrue);
        expect(async.value, isNotNull);
        expect(async.value!.query, '');
        // Asserting the specific filter (not just `isNotNull`) catches a
        // regression where the discovery flip silently drops the filter
        // value while the spinner is showing.
        expect(
          async.value!.filter,
          const PokemonFilter(types: {PokemonTypeId.fire}),
        );
        expect(async.value!.isDiscovery, isTrue);

        completer.complete(Ok(_page(200, 1)));
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('applyFilter enters discovery synchronously', () async {
      await pumpInitial();

      const filter = PokemonFilter(types: {PokemonTypeId.fire});
      container.read(pokemonListViewModelProvider.notifier).applyFilter(filter);
      await Future<void>.delayed(Duration.zero);

      final state = valueOrThrow(container);
      expect(state.isDiscovery, isTrue);
      expect(state.filter, filter);
      verify(
        () => findPokemon.call(
          sort: SortCriteria.numberAsc,
          filter: filter,
        ),
      ).called(1);
    });

    test(
      'selectGeneration composes generationId into the wire filter',
      () async {
        await pumpInitial();

        container
            .read(pokemonListViewModelProvider.notifier)
            .selectGeneration(2);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => findPokemon.call(
            sort: SortCriteria.numberAsc,
            filter: const PokemonFilter(generationId: 2),
          ),
        ).called(1);
      },
    );

    test('changeSort to non-default enters discovery', () async {
      await pumpInitial();

      container
          .read(pokemonListViewModelProvider.notifier)
          .changeSort(SortCriteria.nameAsc);
      await Future<void>.delayed(Duration.zero);

      final state = valueOrThrow(container);
      expect(state.isDiscovery, isTrue);
      verify(
        () => findPokemon.call(sort: SortCriteria.nameAsc),
      ).called(1);
    });

    test('discovery → browse resubscribes the stream', () async {
      await pumpInitial();

      // Flip to discovery.
      container
          .read(pokemonListViewModelProvider.notifier)
          .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
      await Future<void>.delayed(Duration.zero);
      expect(cacheController.hasListener, isFalse);

      // Flip back to browse.
      container.read(pokemonListViewModelProvider.notifier).applyFilter(null);
      await Future<void>.delayed(Duration.zero);

      expect(cacheController.hasListener, isTrue);
      cacheController.add(_page(1, 10));
      await Future<void>.delayed(Duration.zero);
      expect(valueOrThrow(container).items.length, 10);
    });

    test(
      'discovery → browse unblocks loadMore in the pre-stream race window '
      '(resolved review-100 #2)',
      () async {
        await pumpInitial();

        // Flip to discovery — sets hasMore: false (findPokemon is unpaginated).
        container
            .read(pokemonListViewModelProvider.notifier)
            .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
        await Future<void>.delayed(Duration.zero);
        expect(valueOrThrow(container).hasMore, isFalse);

        // Flip back to browse — the stream is re-subscribed but has not yet
        // emitted. Before the fix, hasMore stayed false here and loadMore
        // was blocked by its `!hasMore` guard.
        container.read(pokemonListViewModelProvider.notifier).applyFilter(null);
        await Future<void>.delayed(Duration.zero);
        expect(valueOrThrow(container).hasMore, isTrue);

        // loadMore should actually issue a page fetch in this window.
        clearInteractions(getList);
        when(
          () => getList.call(limit: 24, offset: any(named: 'offset')),
        ).thenAnswer(
          (_) async => Ok(PokemonPage(items: _page(25, 5), hasMore: false)),
        );
        await container.read(pokemonListViewModelProvider.notifier).loadMore();
        verify(
          () => getList.call(limit: 24, offset: any(named: 'offset')),
        ).called(1);
      },
    );

    test(
      'discovery → AsyncError on findPokemon failure preserves inputs',
      () async {
        await pumpInitial();

        when(
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => const Err(CacheFailure()));

        container.read(pokemonListViewModelProvider.notifier).search('boom');
        await Future<void>.delayed(_overDebounce);
        await Future<void>.delayed(Duration.zero);

        final async = container.read(pokemonListViewModelProvider);
        expect(async.hasError, isTrue);
        expect(async.value, isNotNull);
        expect(async.value!.query, 'boom');
      },
    );
  });

  group('PokemonListViewModel — refresh', () {
    test('browse refresh replaces page 0 and clears refreshError', () async {
      await pumpInitial();

      when(
        () => getList.call(limit: 24, offset: 0),
      ).thenAnswer(
        (_) async => Ok(PokemonPage(items: _page(1, 5), hasMore: false)),
      );

      await container.read(pokemonListViewModelProvider.notifier).refresh();

      final state = valueOrThrow(container);
      expect(state.items.length, 5);
      expect(state.offset, 5);
      expect(state.hasMore, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.refreshError, isNull);
    });

    test(
      'browse refresh sets refreshError when getPokemonList fails',
      () async {
        await pumpInitial();

        when(
          () => getList.call(limit: 24, offset: 0),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        await container.read(pokemonListViewModelProvider.notifier).refresh();

        final state = valueOrThrow(container);
        expect(state.isRefreshing, isFalse);
        expect(state.refreshError, isA<NetworkFailure>());
      },
    );

    test(
      'discovery refresh: getPokemonList then findPokemon (resolved blocker 2)',
      () async {
        await pumpInitial();

        container
            .read(pokemonListViewModelProvider.notifier)
            .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
        await Future<void>.delayed(Duration.zero);
        clearInteractions(getList);
        clearInteractions(findPokemon);

        when(
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => Ok(_page(300, 2)));

        await container.read(pokemonListViewModelProvider.notifier).refresh();

        // Order: page fetch first, then find.
        verifyInOrder([
          () => getList.call(limit: 24, offset: 0),
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ]);
        expect(valueOrThrow(container).items.length, 2);
      },
    );

    test(
      'browse refresh resets isLoadingMore when a loadMore is in flight '
      '(resolved review-100 #1)',
      () async {
        await pumpInitial();

        // Hang the page-1 fetch so loadMore stays in flight while refresh runs.
        final loadMoreCompleter = Completer<Result<PokemonPage>>();
        when(
          () => getList.call(limit: 24, offset: 24),
        ).thenAnswer((_) => loadMoreCompleter.future);

        final vm = container.read(pokemonListViewModelProvider.notifier);
        unawaited(vm.loadMore());
        await Future<void>.delayed(Duration.zero);
        expect(valueOrThrow(container).isLoadingMore, isTrue);

        // Refresh page-0 succeeds and must take ownership of isLoadingMore.
        when(
          () => getList.call(limit: 24, offset: 0),
        ).thenAnswer(
          (_) async => Ok(PokemonPage(items: _page(1, 5), hasMore: false)),
        );
        await vm.refresh();

        expect(valueOrThrow(container).isLoadingMore, isFalse);

        // Drain the hanging loadMore so the test cleans up.
        loadMoreCompleter.complete(
          Ok(PokemonPage(items: _page(25, 1), hasMore: false)),
        );
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'browse refresh resets isLoadingMore on Err path '
      '(resolved review-100 #1)',
      () async {
        await pumpInitial();

        final loadMoreCompleter = Completer<Result<PokemonPage>>();
        when(
          () => getList.call(limit: 24, offset: 24),
        ).thenAnswer((_) => loadMoreCompleter.future);

        final vm = container.read(pokemonListViewModelProvider.notifier);
        unawaited(vm.loadMore());
        await Future<void>.delayed(Duration.zero);

        when(
          () => getList.call(limit: 24, offset: 0),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await vm.refresh();

        expect(valueOrThrow(container).isLoadingMore, isFalse);

        loadMoreCompleter.complete(
          Ok(PokemonPage(items: _page(25, 1), hasMore: false)),
        );
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'discovery refresh surfaces a findPokemon failure as refreshError '
      '(resolved test-quality B2)',
      () async {
        await pumpInitial();

        container
            .read(pokemonListViewModelProvider.notifier)
            .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
        await Future<void>.delayed(Duration.zero);

        // Page fetch refreshes the cache successfully…
        when(
          () => getList.call(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => Ok(PokemonPage(items: _page(1, 4), hasMore: false)),
        );
        // …but the find against the freshened cache fails.
        when(
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => const Err(CacheFailure()));

        await container.read(pokemonListViewModelProvider.notifier).refresh();

        final state = valueOrThrow(container);
        expect(state.isRefreshing, isFalse);
        expect(state.refreshError, isA<CacheFailure>());
      },
    );
  });

  group(
    'PokemonListViewModel — discovery race guard (resolved VGV F2)',
    () {
      test(
        'a slow-resolving discovery does not overwrite a faster fresher one',
        () async {
          await pumpInitial();
          final vm = container.read(pokemonListViewModelProvider.notifier);

          // Slow call resolves AFTER the fast one. The slow call's captured
          // pre-await snapshot has only the fire filter; without the
          // discovery seq guard, its `Ok(slowItems)` write would clobber the
          // fast call's already-applied result.
          final slowCompleter = Completer<Result<List<Pokemon>>>();
          when(
            () => findPokemon.call(
              sort: any(named: 'sort'),
              query: any(named: 'query'),
              filter: const PokemonFilter(types: {PokemonTypeId.fire}),
            ),
          ).thenAnswer((_) => slowCompleter.future);

          final fastItems = _page(800, 4);
          when(
            () => findPokemon.call(
              sort: any(named: 'sort'),
              query: any(named: 'query'),
              filter: const PokemonFilter(types: {PokemonTypeId.water}),
            ),
          ).thenAnswer((_) async => Ok(fastItems));

          // Kick off slow discovery (fire). It will await findPokemon.
          vm.applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
          await Future<void>.delayed(Duration.zero);

          // Replace with a fresher filter (water) which resolves immediately.
          vm.applyFilter(const PokemonFilter(types: {PokemonTypeId.water}));
          await Future<void>.delayed(Duration.zero);

          // Fast result has landed; the items should be the water page.
          expect(valueOrThrow(container).items, fastItems);

          // Now let the slow (stale) call complete with a different list.
          slowCompleter.complete(Ok(_page(900, 7)));
          await Future<void>.delayed(Duration.zero);

          // Stale resolution must be ignored — items still reflect the
          // fresher water-filter result.
          expect(
            valueOrThrow(container).items,
            fastItems,
            reason:
                'A stale discovery resolution overwrote the freshest state.',
          );
        },
      );
    },
  );

  group('PokemonListViewModel — leak safety (resolved blocker 7)', () {
    test('5 rapid mode flips do not leak stream subscriptions', () async {
      await pumpInitial();
      expect(cacheController.hasListener, isTrue);

      final vm = container.read(pokemonListViewModelProvider.notifier)
        ..search('a')
        ..search('')
        ..search('b')
        ..search('')
        ..search('c');

      // Wait past the debounce; the final value 'c' transitions to discovery.
      await Future<void>.delayed(_overDebounce);
      await Future<void>.delayed(Duration.zero);

      // Debounce coalesced the rapid input into a single findPokemon call.
      verify(
        () => findPokemon.call(
          sort: SortCriteria.numberAsc,
          query: 'c',
        ),
      ).called(1);

      // Discovery cancels the watch subscription cleanly — no leak.
      expect(cacheController.hasListener, isFalse);

      // Flipping back to browse re-subscribes exactly once.
      vm.search('');
      await Future<void>.delayed(_overDebounce);
      await Future<void>.delayed(Duration.zero);

      expect(cacheController.hasListener, isTrue);
    });

    test('disposing the container cancels timer + subscription', () async {
      await pumpInitial();

      container.read(pokemonListViewModelProvider.notifier).search('pending');

      expect(cacheController.hasListener, isTrue);
      container.dispose();

      expect(cacheController.hasListener, isFalse);
    });
  });

  group('PokemonListViewModel — identity-update guards', () {
    test(
      'applyFilter with the active filter value does not re-run findPokemon',
      () async {
        await pumpInitial();
        const fire = PokemonFilter(types: {PokemonTypeId.fire});

        container.read(pokemonListViewModelProvider.notifier).applyFilter(fire);
        await Future<void>.delayed(Duration.zero);
        clearInteractions(findPokemon);

        container.read(pokemonListViewModelProvider.notifier).applyFilter(fire);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        );
      },
    );

    test(
      'changeSort with the active criterion does not re-run findPokemon',
      () async {
        await pumpInitial();

        container
            .read(pokemonListViewModelProvider.notifier)
            .changeSort(SortCriteria.nameAsc);
        await Future<void>.delayed(Duration.zero);
        clearInteractions(findPokemon);

        container
            .read(pokemonListViewModelProvider.notifier)
            .changeSort(SortCriteria.nameAsc);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        );
      },
    );

    test(
      'selectGeneration with the active id does not re-run findPokemon',
      () async {
        await pumpInitial();

        container
            .read(pokemonListViewModelProvider.notifier)
            .selectGeneration(2);
        await Future<void>.delayed(Duration.zero);
        clearInteractions(findPokemon);

        container
            .read(pokemonListViewModelProvider.notifier)
            .selectGeneration(2);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        );
      },
    );
  });

  group(
    'PokemonListViewModel — _composeFilter (PR1 groundwork × PR2 wiring)',
    () {
      test(
        'composes filter + generationId into a single PokemonFilter on '
        'findPokemon',
        () async {
          await pumpInitial();

          container
              .read(pokemonListViewModelProvider.notifier)
              .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
          await Future<void>.delayed(Duration.zero);

          container
              .read(pokemonListViewModelProvider.notifier)
              .selectGeneration(3);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => findPokemon.call(
              sort: SortCriteria.numberAsc,
              filter: const PokemonFilter(
                types: {PokemonTypeId.fire},
                generationId: 3,
              ),
            ),
          ).called(1);
        },
      );
    },
  );

  group('PokemonListViewModel — analytics (T-30b §12)', () {
    test(
      'build emits list_viewed{origin: cold} with the rendered count',
      () async {
        await pumpInitial();

        final viewed = analytics.named('list_viewed');
        expect(viewed, hasLength(1));
        expect(viewed.single.parameters, {'origin': 'cold', 'count': 24});
      },
    );

    test(
      'clearing discovery back to browse emits list_viewed{origin: warm}',
      () async {
        await pumpInitial();
        final vm = container.read(pokemonListViewModelProvider.notifier)
          ..applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
        await Future<void>.delayed(Duration.zero);

        // Clearing every axis returns to browse → _enterBrowse → warm view.
        vm.applyFilter(null);
        await Future<void>.delayed(Duration.zero);

        final viewed = analytics.named('list_viewed');
        expect(viewed.map((e) => e.parameters['origin']), ['cold', 'warm']);
        // findPokemon stub returns a 3-item page; the warm view reports that
        // count — guards against a count regression on browse re-entry.
        expect(viewed.last.parameters, {'origin': 'warm', 'count': 3});
      },
    );

    test(
      'search emits search_performed with result_count only (RNF-09)',
      () async {
        await pumpInitial();

        container.read(pokemonListViewModelProvider.notifier).search('pikachu');
        await Future<void>.delayed(_overDebounce);
        await Future<void>.delayed(Duration.zero);

        final searched = analytics.named('search_performed');
        expect(searched, hasLength(1));
        // findPokemon stub returns a 3-item page; the term never appears.
        expect(searched.single.parameters, {'result_count': 3});
      },
    );

    test('applyFilter emits filter_applied presence flags', () async {
      await pumpInitial();

      container
          .read(pokemonListViewModelProvider.notifier)
          .applyFilter(
            const PokemonFilter(
              types: {PokemonTypeId.fire},
              height: HeightCategory.tall,
            ),
          );

      final applied = analytics.named('filter_applied');
      expect(applied, hasLength(1));
      expect(applied.single.parameters, {
        'has_type': true,
        'has_weakness': false,
        'has_height': true,
      });

      // Clearing the filter is still a filter_applied — with all flags false.
      container.read(pokemonListViewModelProvider.notifier).applyFilter(null);

      expect(analytics.named('filter_applied'), hasLength(2));
      expect(analytics.named('filter_applied').last.parameters, {
        'has_type': false,
        'has_weakness': false,
        'has_height': false,
      });
    });

    test('changeSort emits sort_changed with the criterion name', () async {
      await pumpInitial();

      container
          .read(pokemonListViewModelProvider.notifier)
          .changeSort(SortCriteria.nameAsc);

      expect(
        analytics.named('sort_changed').single.parameters,
        {'criteria': 'nameAsc'},
      );
    });

    test(
      'selectGeneration emits generation_selected; clearing does not',
      () async {
        await pumpInitial();
        final vm = container.read(pokemonListViewModelProvider.notifier)
          ..selectGeneration(3);
        await Future<void>.delayed(Duration.zero);

        expect(
          analytics.named('generation_selected').single.parameters,
          {'generation': 3},
        );

        // Clearing the generation is a deselection — not an event.
        vm.selectGeneration(null);
        await Future<void>.delayed(Duration.zero);
        expect(analytics.named('generation_selected'), hasLength(1));
      },
    );

    test(
      'swallowed loadMore failure reports captureError and emits error_shown',
      () async {
        await pumpInitial();

        when(
          () => getList.call(limit: 24, offset: 24),
        ).thenAnswer((_) async => const Err(RateLimitFailure()));

        await container.read(pokemonListViewModelProvider.notifier).loadMore();

        // error_shown carries the mapped TE code (TE-08) + screen.
        final shown = analytics.named('error_shown');
        expect(shown, hasLength(1));
        expect(shown.single.parameters, {
          'te_code': 'TE-08',
          'screen': 'pokemon_list',
        });
        // The handled failure is captured with its typed Failure.
        expect(reporter.captured, hasLength(1));
        expect(reporter.captured.single.failure, isA<RateLimitFailure>());
      },
    );

    test(
      'browse refresh failure reports the handled failure (TE-02 banner)',
      () async {
        await pumpInitial();

        when(
          () => getList.call(limit: 24, offset: 0),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        await container.read(pokemonListViewModelProvider.notifier).refresh();

        expect(reporter.captured, hasLength(1));
        expect(reporter.captured.single.failure, isA<NetworkFailure>());
      },
    );
  });
}
