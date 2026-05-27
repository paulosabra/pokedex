import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/ui/components/search_field.dart';
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
/// the search field, and a single-column scrollable list of `PokemonCard`s.
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
    final result = await showModalBottomSheet<FiltersSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FiltersSheet(initial: state.filter),
    );
    if (!mounted || result == null) return;
    ref.read(pokemonListViewModelProvider.notifier).applyFilter(result.value);
  }

  Future<void> _openSort(PokemonListState state) async {
    final result = await showModalBottomSheet<SortCriteria?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SortSheet(initial: state.sort),
    );
    if (!mounted || result == null) return;
    ref.read(pokemonListViewModelProvider.notifier).changeSort(result);
  }

  Future<void> _openGenerations(PokemonListState state) async {
    final result = await showModalBottomSheet<GenerationsSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GenerationsSheet(initial: state.generationId),
    );
    if (!mounted || result == null) return;
    ref
        .read(pokemonListViewModelProvider.notifier)
        .selectGeneration(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pokemonListViewModelProvider);
    final state = async.value;

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
                Expanded(
                  child: _Body(
                    async: async,
                    scrollController: _scrollController,
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
  const _Body({required this.async, required this.scrollController});

  final AsyncValue<PokemonListState> async;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = async.value;
    if (async.isLoading && state == null) {
      return const _SkeletonList();
    }
    if (state == null) {
      // Pure error with no previous data; PR4 will swap this for a richer
      // error widget. For PR2 we render a minimal message + retry.
      return _ErrorBlock(
        error: async.error,
        onRetry: () =>
            ref.read(pokemonListViewModelProvider.notifier).refresh(),
      );
    }
    if (state.items.isEmpty && !async.isLoading) {
      return _EmptyBlock(state: state);
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(pokemonListViewModelProvider.notifier).refresh(),
      child: _PokemonList(state: state, scrollController: scrollController),
    );
  }
}

class _PokemonList extends StatelessWidget {
  const _PokemonList({required this.state, required this.scrollController});

  final PokemonListState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final showFooterSpinner = state.isLoadingMore;
    final itemCount = items.length + (showFooterSpinner ? 1 : 0);
    return ListView.separated(
      key: const PageStorageKey<String>('pokemon-list'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 15),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return PokemonCard(pokemon: items[index]);
      },
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
        height: 115,
        decoration: BoxDecoration(
          color: AppColors.backgroundInput,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.state});

  final PokemonListState state;

  String _message() {
    if (state.query.isNotEmpty) {
      // TE-04
      return 'No Pokémon found for "${state.query}".';
    }
    // TE-05 / RN-15 partial-generation case (refined widget lands in PR4)
    return 'No Pokémon match the current filters.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _message(),
          textAlign: TextAlign.center,
          style: AppTypography.description,
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Something went wrong loading Pokémon.',
              textAlign: TextAlign.center,
              style: AppTypography.description,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
