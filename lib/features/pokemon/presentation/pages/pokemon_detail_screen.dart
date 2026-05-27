import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/app/layout/master_detail_scaffold.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/states/generic_error_widget.dart';
import 'package:pokedex/core/ui/states/offline_error_widget.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';
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
    final body = async.when(
      data: (detail) => _Loaded(detail: detail),
      loading: () => const _Loading(),
      error: (error, _) => _Error(error: error),
    );
    // RF-46: on expanded breakpoints, frame the detail as the right panel of
    // a master-detail layout with the list rendering as the master panel.
    // `MasterDetailScaffold` returns [body] verbatim on compact/medium.
    return MasterDetailScaffold(
      masterBuilder: (_) => const PokemonListScreen(),
      child: body,
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

/// Faint white pokeball watermark + the three-tab row. The pokeball tracks
/// the active tab horizontally (Figma `Pokeball` `321:426` / `321:494`) so
/// it sits behind whichever tab is currently selected, extending upward
/// into the colored header via [Clip.none].
class _Tabs extends StatefulWidget {
  const _Tabs();

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  TabController? _controller;
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (_controller != next) {
      _animation?.removeListener(_handleTick);
      _controller = next;
      _animation = next.animation;
      _animation?.addListener(_handleTick);
    }
  }

  @override
  void dispose() {
    _animation?.removeListener(_handleTick);
    super.dispose();
  }

  void _handleTick() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final value = _animation?.value ?? controller.index.toDouble();
    return SizedBox(
      height: 45,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / controller.length;
          const pokeballSize = 100.0;
          final left = tabWidth * value + (tabWidth - pokeballSize) / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: -pokeballSize / 2,
                width: pokeballSize,
                height: pokeballSize,
                child: const _PokeballWatermark(),
              ),
              const TabBar(
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
            ],
          );
        },
      ),
    );
  }
}

class _PokeballWatermark extends StatelessWidget {
  const _PokeballWatermark();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/illustrations/pokeball.svg',
      colorFilter: const ColorFilter.mode(
        Color(0x33FFFFFF),
        BlendMode.srcIn,
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
    // No AppBar — the error widget's centered CTA is the single Back
    // affordance (resolved review finding: two back affordances confuse users
    // and split visual focus).
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: isOffline
          ? OfflineErrorWidget(
              message: 'You are offline and this Pokémon is not cached.',
              retryLabel: 'Back',
              onRetry: () => _back(context),
            )
          : GenericErrorWidget(
              message: 'Could not load this Pokémon.',
              retryLabel: 'Back',
              onRetry: () => _back(context),
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
