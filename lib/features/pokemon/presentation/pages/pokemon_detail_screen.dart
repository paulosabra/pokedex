import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_detail_view_model.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/about_tab.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/detail_header.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/evolution_tab.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/stats_tab.dart';

/// The Pokémon detail screen (UC-06/07).
///
/// Hosts the [DetailHeader], a three-tab layout (About / Stats / Evolution),
/// and the routed tab views. The background is the Pokémon's primary type
/// color (RN-04); the tab content lives inside a white rounded panel.
///
/// Watches [pokemonDetailViewModelProvider] keyed on [id]. The Evolution tab
/// watches its own provider (resolved refine 7) so About + Stats render
/// immediately while the evolution chain loads.
class PokemonDetailScreen extends ConsumerWidget {
  /// Creates a [PokemonDetailScreen] for the Pokémon at [id].
  const PokemonDetailScreen({required this.id, super.key});

  /// The National Dex id parsed from the route's `:id` segment.
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pokemonDetailViewModelProvider(id));
    return async.when(
      data: (detail) => _Loaded(detail: detail),
      loading: () => const _Loading(),
      error: (error, _) => _Error(error: error),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    final types = detail.summary.types;
    // Defensive: PokéAPI rows with no mapped types fall back to normal so the
    // screen still renders instead of throwing. The mapper drops unrecognised
    // type names, so this guards an edge case (e.g. a future region/type the
    // app hasn't shipped a mapping for).
    final primary = types.isEmpty ? PokemonTypeId.normal : types.first;
    final secondary = types.length > 1 ? types[1] : null;
    final style = PokemonTypeTheme.styleOf(primary);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: style.backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              DetailHeader(
                id: detail.summary.id,
                name: detail.summary.name,
                primaryType: primary,
                secondaryType: secondary,
                imageUrl: detail.summary.imageUrl,
                onBack: () => _back(context),
              ),
              const _Tabs(),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: ColoredBox(
                    color: AppColors.backgroundWhite,
                    child: TabBarView(
                      children: [
                        AboutTab(detail: detail, accent: style.color),
                        StatsTab(detail: detail, accent: style.color),
                        EvolutionTab(
                          id: detail.summary.id,
                          accent: style.color,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 45,
      child: TabBar(
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        labelColor: AppColors.textWhite,
        labelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textWhite,
        ),
        unselectedLabelColor: Color(0x80FFFFFF),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        tabs: [
          Tab(text: 'About'),
          Tab(text: 'Stats'),
          Tab(text: 'Evolution'),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final isOffline = error is NetworkFailure || error is CacheFailure;
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
          tooltip: 'Back',
          onPressed: () => _back(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.error_outline,
                size: 48,
                color: AppColors.textGray,
              ),
              const SizedBox(height: 16),
              Text(
                isOffline
                    ? 'You are offline and this Pokémon is not cached.'
                    : 'Could not load this Pokémon.',
                textAlign: TextAlign.center,
                style: AppTypography.description,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _back(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pops if there's a route to pop, otherwise routes to the list. Deep-linking
/// straight to `/pokemon/:id` leaves nothing on the stack to pop, so the back
/// affordance lands the user on the list instead of an empty history.
void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
