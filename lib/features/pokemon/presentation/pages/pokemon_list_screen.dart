import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pokedex/app/layout/breakpoints.dart';
import 'package:pokedex/app/layout/responsive_layout.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/ui/components/pokemon_card.dart' as core;
import 'package:pokedex/core/ui/components/search_field.dart';
import 'package:pokedex/core/ui/states/empty_filter_widget.dart';
import 'package:pokedex/core/ui/states/empty_generation_widget.dart';
import 'package:pokedex/core/ui/states/empty_search_widget.dart';
import 'package:pokedex/core/ui/states/generic_error_widget.dart';
import 'package:pokedex/core/ui/states/offline_error_widget.dart';
import 'package:pokedex/core/ui/states/stale_cache_banner.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/presentation/state/pokemon_list_state.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_list_view_model.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/pokemon_card.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/filters_sheet.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/generations_sheet.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/sort_sheet.dart';

/// The Home / browse screen (UC-01..UC-05, UC-08).
///
/// Matches the Figma Home mockup (`321:675`): no AppBar — instead a custom
/// header with the Pokeball watermark, the Generation/Sort/Filter icons in
/// the top-right corner, a 32pt Bold "Pokédex" title, a 16pt Regular subtitle,
/// the search field, and a scrollable list/grid of `PokemonCard`s adapted to
/// the active breakpoint (1 / 2 / 3 columns at compact / medium / expanded).
///
/// Error/empty states route through `lib/core/ui/states/`; sheet vs dialog
/// modality is chosen by [ResponsiveLayout.showSheetOrDialog] at invocation.
class PokemonListScreen extends ConsumerStatefulWidget {
  /// Creates the [PokemonListScreen].
  const PokemonListScreen({super.key});

  @override
  ConsumerState<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends ConsumerState<PokemonListScreen> {
  static const double _loadMoreThreshold = 200;

  late final ScrollController _scrollController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThreshold) {
      unawaited(
        ref.read(pokemonListViewModelProvider.notifier).loadMore(),
      );
    }
  }

  Future<void> _openFilters(PokemonListState state) async {
    final result = await ResponsiveLayout.showSheetOrDialog<FiltersSheetResult>(
      context: context,
      builder: (_) => FiltersSheet(initial: state.filter),
    );
    if (!mounted || result == null) return;
    ref.read(pokemonListViewModelProvider.notifier).applyFilter(result.value);
  }

  Future<void> _openSort(PokemonListState state) async {
    final result = await ResponsiveLayout.showSheetOrDialog<SortCriteria?>(
      context: context,
      builder: (_) => SortSheet(initial: state.sort),
    );
    if (!mounted || result == null) return;
    ref.read(pokemonListViewModelProvider.notifier).changeSort(result);
  }

  Future<void> _openGenerations(PokemonListState state) async {
    final result =
        await ResponsiveLayout.showSheetOrDialog<GenerationsSheetResult>(
          context: context,
          builder: (_) => GenerationsSheet(initial: state.generationId),
        );
    if (!mounted || result == null) return;
    ref
        .read(pokemonListViewModelProvider.notifier)
        .selectGeneration(result.value);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(pokemonListViewModelProvider.notifier).search('');
  }

  void _clearFilter() {
    ref.read(pokemonListViewModelProvider.notifier).applyFilter(null);
  }

  Future<void> _refresh() {
    return ref.read(pokemonListViewModelProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pokemonListViewModelProvider);
    final state = async.value;
    final breakpoint = Breakpoint.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Stack(
        children: [
          const _HeaderPokeballWatermark(),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  onFilterTap: state == null ? null : () => _openFilters(state),
                  onSortTap: state == null ? null : () => _openSort(state),
                  onGenerationTap: state == null
                      ? null
                      : () => _openGenerations(state),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 11, 40, 0),
                  child: SearchField(
                    controller: _searchController,
                    onChanged: (q) => ref
                        .read(pokemonListViewModelProvider.notifier)
                        .search(q),
                  ),
                ),
                const SizedBox(height: 20),
                if (state != null && state.refreshError != null) ...[
                  const StaleCacheBanner(),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: _Body(
                    async: async,
                    scrollController: _scrollController,
                    breakpoint: breakpoint,
                    onRefresh: _refresh,
                    onClearSearch: _clearSearch,
                    onClearFilter: _clearFilter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The faint Pokeball motif behind the screen title — Figma node `321:676`,
/// anchored at top:-207 left:0 so only the lower half peeks through.
class _HeaderPokeballWatermark extends StatelessWidget {
  const _HeaderPokeballWatermark();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: -207,
      width: 414,
      height: 414,
      child: IgnorePointer(
        child: SvgPicture.asset('assets/illustrations/pokeball.svg'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onFilterTap,
    required this.onSortTap,
    required this.onGenerationTap,
  });

  final VoidCallback? onFilterTap;
  final VoidCallback? onSortTap;
  final VoidCallback? onGenerationTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _HeaderIcon(
                asset: 'assets/icons/header/generation.svg',
                tooltip: 'Generations',
                onTap: onGenerationTap,
              ),
              const SizedBox(width: 20),
              _HeaderIcon(
                asset: 'assets/icons/header/sort.svg',
                tooltip: 'Sort',
                onTap: onSortTap,
              ),
              const SizedBox(width: 20),
              _HeaderIcon(
                asset: 'assets/icons/header/filter.svg',
                tooltip: 'Filters',
                onTap: onFilterTap,
              ),
            ],
          ),
          const SizedBox(height: 35),
          const Text('Pokédex', style: AppTypography.applicationTitle),
          const SizedBox(height: 16),
          const Text(
            'Search for Pokémon by name or using the National Pokédex number.',
            style: AppTypography.description,
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.asset,
    required this.tooltip,
    required this.onTap,
  });

  final String asset;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SvgPicture.asset(asset, width: 25, height: 25),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.async,
    required this.scrollController,
    required this.breakpoint,
    required this.onRefresh,
    required this.onClearSearch,
    required this.onClearFilter,
  });

  final AsyncValue<PokemonListState> async;
  final ScrollController scrollController;
  final Breakpoint breakpoint;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = async.value;

    // Pure error path: no usable state to fall back on. Checked BEFORE the
    // skeleton branch — Riverpod can emit `AsyncLoading.copyWithPrevious(
    // AsyncError)` immediately after a failed build, which has both
    // `isLoading == true` and `hasError == true`. Showing the error widget
    // in that frame is the right behavior (the user sees the failure, not a
    // misleading spinner).
    if (state == null && async.hasError) {
      final error = async.error;
      if (error is NetworkFailure || error is CacheFailure) {
        return OfflineErrorWidget(onRetry: onRefresh);
      }
      return GenericErrorWidget(onRetry: onRefresh);
    }

    // Initial load with no cached state yet.
    if (async.isLoading && state == null) {
      return const _SkeletonList();
    }

    if (state == null) {
      // Defensive — the prior branches cover loading and error; this only
      // fires if the AsyncValue is in some unexpected new shape. Render the
      // generic widget instead of leaving the body blank (PRD §8.1).
      return GenericErrorWidget(onRetry: onRefresh);
    }

    // We have items — render them (with optional stale banner already above).
    if (state.items.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: _PokemonGrid(
          state: state,
          scrollController: scrollController,
          columns: ResponsiveLayout.gridColumns(breakpoint),
        ),
      );
    }

    // No items, no refresh in flight — pick the right empty variant.
    return _EmptyState(
      state: state,
      onClearSearch: onClearSearch,
      onClearFilter: onClearFilter,
      onRetry: onRefresh,
    );
  }
}

class _PokemonGrid extends StatelessWidget {
  const _PokemonGrid({
    required this.state,
    required this.scrollController,
    required this.columns,
  });

  final PokemonListState state;
  final ScrollController scrollController;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final showFooterSpinner = state.isLoadingMore;
    final itemCount = items.length + (showFooterSpinner ? 1 : 0);

    if (columns == 1) {
      return ListView.separated(
        key: const PageStorageKey<String>('pokemon-list'),
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 15),
        itemBuilder: (context, index) {
          if (index >= items.length) return const _FooterSpinner();
          return PokemonCard(pokemon: items[index]);
        },
      );
    }

    // Multi-column layouts use a grid. The card's intrinsic stacked layout
    // needs the full 130 logical px of height regardless of column count, so
    // we lock `mainAxisExtent` instead of letting the grid stretch the tile.
    return GridView.builder(
      key: const PageStorageKey<String>('pokemon-list'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: core.PokemonCard.height,
        crossAxisSpacing: 16,
        mainAxisSpacing: 15,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= items.length) return const _FooterSpinner();
        return PokemonCard(pokemon: items[index]);
      },
    );
  }
}

class _FooterSpinner extends StatelessWidget {
  const _FooterSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 15),
      itemBuilder: (_, _) => Container(
        height: core.PokemonCard.height,
        decoration: BoxDecoration(
          color: AppColors.backgroundInput,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.state,
    required this.onClearSearch,
    required this.onClearFilter,
    required this.onRetry,
  });

  final PokemonListState state;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilter;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    // TE-04: search returned no results — show the query verbatim.
    if (state.query.isNotEmpty) {
      return EmptySearchWidget(query: state.query, onClear: onClearSearch);
    }
    // RN-15: partial-generation backfill — distinct from "filter excludes
    // everything" because the recovery is "refresh to fetch missing data".
    // `state.filter?.isEmpty ?? true` keeps `PokemonFilter`'s field
    // enumeration where it belongs (the entity), so a new filter axis
    // doesn't silently break this branch.
    if (state.generationId != null && (state.filter?.isEmpty ?? true)) {
      return EmptyGenerationWidget(
        generationLabel: 'Gen ${state.generationId}',
        onRetry: () => unawaited(onRetry()),
      );
    }
    // TE-05: a filter is active but no rows satisfy the intersection.
    return EmptyFilterWidget(onClear: onClearFilter);
  }
}
