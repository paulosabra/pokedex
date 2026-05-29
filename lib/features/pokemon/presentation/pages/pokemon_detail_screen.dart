import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/app/layout/master_detail_scaffold.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/observability_providers.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/shimmer_box.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';
import 'package:pokedex/core/ui/states/generic_error_widget.dart';
import 'package:pokedex/core/ui/states/offline_error_widget.dart';
import 'package:pokedex/core/utils/string_utils.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/presentation/analytics/error_te_code.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_detail_view_model.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/about_tab.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/evolution_tab.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/stats_tab.dart';

/// The Pokémon detail screen (UC-06/07).
///
/// Hosts a collapsible AppBar that mirrors Figma `Profile #2 - About`
/// (`321:416`): the expanded state shows the upper-case Name silhouette
/// (110pt/Bold) as a translucent watermark with the ID, official artwork,
/// small Name and Type badges in front. As the user scrolls, the expanded
/// composition fades and the AppBar collapses to its standard toolbar height
/// with the Name centered as the title.
///
/// The tab strip (About / Stats / Evolution) pins below the AppBar via
/// `SliverAppBar.bottom`. The tab body sits inside a rounded white sheet.
/// Watches [pokemonDetailViewModelProvider] keyed on [id]; the Evolution tab
/// watches its own provider so About + Stats render immediately while the
/// evolution chain loads.
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
      masterBuilder: (_) => const PokemonListScreen(compact: true),
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
    final style = PokemonTypeTheme.styleOf(primary);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: style.backgroundColor,
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            _DetailSliverAppBar(
              detail: detail,
              background: style.backgroundColor,
            ),
          ],
          // Wrapping the body in ClipRRect keeps the white sheet's rounded
          // top corners visible immediately under the pinned tabs at every
          // scroll position — matching Figma `Bottom Background` (`321:430`).
          body: ClipRRect(
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
      ),
    );
  }
}

/// SliverAppBar that drives the scroll-collapse transition. Fully expanded it
/// is [_expandedHeight] tall and renders [_ExpandedHeader] (silhouette + dot
/// pattern + photo + ID/Name/Type); collapsed, it shrinks to [kToolbarHeight]
/// + [_tabsHeight] with just the centered Name as title.
class _DetailSliverAppBar extends StatelessWidget {
  const _DetailSliverAppBar({
    required this.detail,
    required this.background,
  });

  static const double _expandedHeight = 280;
  static const double _tabsHeight = 45;

  final PokemonDetail detail;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight,
      backgroundColor: background,
      foregroundColor: AppColors.textWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back, color: AppColors.textWhite),
        onPressed: () => _back(context),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // [t] is 1.0 when fully expanded and 0.0 when fully collapsed.
          // SliverAppBar's flexibleSpace constraints shrink linearly with
          // scroll, so we can derive the fade fraction without listening to
          // any controller.
          final minHeight =
              kToolbarHeight + _tabsHeight + MediaQuery.paddingOf(context).top;
          final maxHeight = _expandedHeight + MediaQuery.paddingOf(context).top;
          final t =
              ((constraints.maxHeight - minHeight) / (maxHeight - minHeight))
                  .clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Expanded composition (silhouette + dot pattern + hero) fades
              // out as the AppBar collapses.
              Opacity(
                opacity: t,
                child: _ExpandedHeader(
                  detail: detail,
                  background: background,
                ),
              ),
              // Collapsed-state Name centered in the toolbar slot. We render
              // it inside flexibleSpace (rather than using `title:`) so the
              // fade is driven by the same `t` as the expanded content.
              Positioned(
                top: MediaQuery.paddingOf(context).top,
                left: 56, // make room for the leading back button
                right: 56,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 1 - t,
                    child: Center(
                      child: Text(
                        StringUtils.capitalize(detail.summary.name),
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textWhite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(_tabsHeight),
        child: _Tabs(),
      ),
    );
  }
}

/// Expanded-state composition behind the AppBar — Figma `Profile #2 - About`
/// (`321:416`). Renders the watermark Name silhouette across the top, a
/// translucent dot pattern in the top-right corner, and the [_Hero] row
/// (photo + #id + Name + Type badges) anchored toward the bottom.
class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({required this.detail, required this.background});

  final PokemonDetail detail;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    final topPadding = MediaQuery.paddingOf(context).top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Watermark Name silhouette — 110pt Bold, ~25% white. OverflowBox
        // lets long names (e.g. "CHARMANDER", "BULBASAUR") render past both
        // screen edges, matching the Figma reference where the text extends
        // beyond the frame.
        Positioned(
          top: topPadding + 5,
          left: 0,
          right: 0,
          height: 120,
          child: IgnorePointer(
            child: ClipRect(
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                child: ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFFFFFFF).withValues(alpha: 0.3),
                      const Color(0xFFFFFFFF).withValues(alpha: 0),
                    ],
                  ).createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    summary.name.toUpperCase(),
                    style: AppTypography.title.copyWith(
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2
                        ..blendMode = BlendMode.color,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Dot pattern in the top-right corner — Figma `Pattern`
        // (`321:420` / `321:488`).
        Positioned(
          top: topPadding + 25,
          right: 25,
          width: 126,
          height: 82,
          child: const IgnorePointer(child: _DotPattern()),
        ),
        // Hero row anchored just above the tabs: artwork on the left, ID +
        // Name + Type badges stacked on the right.
        Positioned(
          top: topPadding + 60,
          left: 40,
          right: 40,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _Hero(
              id: summary.id,
              name: summary.name,
              imageUrl: summary.imageUrl,
              types: summary.types,
            ),
          ),
        ),
      ],
    );
  }
}

/// Photo + ID + Name + Type badges — the always-visible identity of the
/// Pokémon when the AppBar is expanded.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
  });

  static const double _photoSize = 130;

  final int id;
  final String name;
  final String imageUrl;
  final List<PokemonTypeId> types;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _photoSize,
          height: _photoSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Translucent white pokeball silhouette behind the artwork,
              // echoing the watermark used in the tab strip and stats tab.
              Positioned.fill(
                child: SvgPicture.asset(
                  'assets/illustrations/circle.svg',
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFFFFFFF),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(
                width: _photoSize - 10,
                height: _photoSize - 10,
                child: _PokemonImage(imageUrl: imageUrl),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${id.toString().padLeft(3, '0')}',
                style: AppTypography.filterTitle.copyWith(
                  color: AppColors.textNumber,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                StringUtils.capitalize(name),
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textWhite,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final type in types) TypeBadge(type: type),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PokemonImage extends StatelessWidget {
  const _PokemonImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0x80FFFFFF),
        size: 48,
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) => const Icon(
        Icons.broken_image,
        color: Color(0x80FFFFFF),
        size: 48,
      ),
    );
  }
}

/// 4×6 white-dot grid — Figma `Pattern` (`321:420` / `321:488`).
class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(126, 82),
      painter: _DotPatternPainter(),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter();

  static const _cols = 6;
  static const _rows = 4;
  static const _spacing = 22.0;
  static const _radius = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.textWhite.withValues(alpha: 0.3);
    for (var c = 0; c < _cols; c++) {
      for (var r = 0; r < _rows; r++) {
        canvas.drawCircle(
          Offset(c * _spacing + _radius, r * _spacing + _radius),
          _radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Faint white pokeball watermark + the three-tab row. The pokeball tracks
/// the active tab horizontally (Figma `Pokeball` `321:426` / `321:494`) so
/// it sits behind whichever tab is currently selected.
class _Tabs extends ConsumerStatefulWidget {
  const _Tabs();

  @override
  ConsumerState<_Tabs> createState() => _TabsState();
}

class _TabsState extends ConsumerState<_Tabs> {
  TabController? _controller;
  Animation<double>? _animation;

  /// Last tab index reported to analytics — seeded from the controller's
  /// initial index so the first-shown tab does not count as a change.
  int _reportedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (_controller != next) {
      _animation?.removeListener(_handleTick);
      _controller = next;
      _reportedIndex = next.index;
      _animation = next.animation;
      _animation?.addListener(_handleTick);
    }
  }

  @override
  void dispose() {
    _animation?.removeListener(_handleTick);
    super.dispose();
  }

  void _handleTick() {
    setState(() {});
    _maybeReportTabChange();
  }

  /// PRD §12 `detail_tab_changed`: emit once when the selection settles on a
  /// new tab index — not on every animation frame, and not for the initial
  /// tab (guarded by [_reportedIndex]).
  void _maybeReportTabChange() {
    final index = _controller?.index;
    if (index == null || index == _reportedIndex) return;
    _reportedIndex = index;
    ref
        .read(analyticsServiceProvider)
        .logEvent(DetailTabChanged(tab: _tabForIndex(index)));
  }

  static DetailTab _tabForIndex(int index) => switch (index) {
    0 => DetailTab.about,
    1 => DetailTab.stats,
    _ => DetailTab.evolution,
  };

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final value = _animation?.value ?? controller.index.toDouble();
    return SizedBox(
      height: 45,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / controller.length;
          const pokeballSize = 90.0;
          const halfPokeball = pokeballSize / 2;
          final left = tabWidth * value + (tabWidth - pokeballSize) / 2;
          // The pokeball ornament sits behind the active tab. Per Figma the
          // BOTTOM half is hidden behind the white-sheet rounding below — we
          // render the upper hemisphere only by clipping the SVG's bottom
          // half via the 45-tall Positioned + OverflowBox combo.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                width: pokeballSize,
                height: halfPokeball,
                child: const ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: pokeballSize,
                    child: SizedBox(
                      width: pokeballSize,
                      height: pokeballSize,
                      child: _PokeballWatermark(),
                    ),
                  ),
                ),
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

/// Detail-screen loading state — shimmer-animated skeleton blocks shaped
/// roughly like the loaded layout (header strip, tab strip, content cards)
/// so the user sees the page's silhouette while the detail loads, instead
/// of a context-free spinner.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        bottom: false,
        child: AppShimmer(
          child: Padding(
            padding: EdgeInsets.fromLTRB(40, 16, 40, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonBox(height: 140, borderRadius: 20),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 32)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 32)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 32)),
                  ],
                ),
                SizedBox(height: 24),
                SkeletonBox(height: 100),
                SizedBox(height: 16),
                SkeletonBox(height: 100),
                SizedBox(height: 16),
                SkeletonBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Error extends ConsumerWidget {
  const _Error({required this.error});

  /// `screen` property attached to the detail screen's `error_shown` events.
  static const String _screenName = 'pokemon_detail';

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = error is NetworkFailure || error is CacheFailure;
    void reportShown(String teCode) => ref
        .read(analyticsServiceProvider)
        .logEvent(ErrorShown(teCode: teCode, screen: _screenName));
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
              onShown: () => reportShown(teCodeForError(error)),
            )
          : GenericErrorWidget(
              message: 'Could not load this Pokémon.',
              retryLabel: 'Back',
              onRetry: () => _back(context),
              onShown: () => reportShown(teCodeForError(error)),
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
