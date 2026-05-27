import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// Renders the live `PokemonListViewModel` state, dispatches user intents
/// (search, filter, sort, generation, refresh, loadMore), and opens the three
/// discovery sheets.
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
    if (!mounted || result == null) return; // drag-to-dismiss
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
    if (!mounted || result == null) return; // drag-to-dismiss
    ref
        .read(pokemonListViewModelProvider.notifier)
        .selectGeneration(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pokemonListViewModelProvider);
    final state = async.value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        title: const Text('Pokédex', style: AppTypography.applicationTitle),
      ),
      body: Column(
        children: [
          _SearchAndControlsRow(
            controller: _searchController,
            onSearchChanged: (q) =>
                ref.read(pokemonListViewModelProvider.notifier).search(q),
            onFilterTap: state == null ? null : () => _openFilters(state),
            onSortTap: state == null ? null : () => _openSort(state),
            onGenerationTap: state == null
                ? null
                : () => _openGenerations(state),
          ),
          Expanded(
            child: _Body(async: async, scrollController: _scrollController),
          ),
        ],
      ),
    );
  }
}

class _SearchAndControlsRow extends StatelessWidget {
  const _SearchAndControlsRow({
    required this.controller,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onSortTap,
    required this.onGenerationTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSortTap;
  final VoidCallback? onGenerationTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SearchField(
              controller: controller,
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Filters',
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Sort',
            onPressed: onSortTap,
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            tooltip: 'Generations',
            onPressed: onGenerationTap,
            icon: const Icon(Icons.collections_bookmark_outlined),
          ),
        ],
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
      return const _SkeletonGrid();
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
      child: _PokemonGrid(
        state: state,
        scrollController: scrollController,
      ),
    );
  }
}

class _PokemonGrid extends StatelessWidget {
  const _PokemonGrid({required this.state, required this.scrollController});

  final PokemonListState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final showFooterSpinner = state.isLoadingMore;
    final itemCount = items.length + (showFooterSpinner ? 1 : 0);
    return GridView.builder(
      key: const PageStorageKey<String>('pokemon-list-grid'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        return PokemonCard(pokemon: items[index]);
      },
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => DecoratedBox(
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
