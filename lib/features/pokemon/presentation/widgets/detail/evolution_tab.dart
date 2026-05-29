import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/utils/string_utils.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_evolution_provider.dart';

/// The detail-screen Evolution tab — Figma `Profile #1 - Evolution`
/// (`268:513`).
///
/// Uses [pokemonEvolutionProvider] (resolved refine 7: loads lazily,
/// independent of the detail VM, so About/Stats render first if the chain
/// call is slower). The chain is flattened into a list of (parent → child)
/// pairs so every row uses the same `[card | connector | card]` layout —
/// the previous recursive `Padding(left: 117)` indented later stages and
/// broke the visual alignment between stage 1→2 and stage 2→3.
class EvolutionTab extends ConsumerWidget {
  /// Creates an [EvolutionTab].
  const EvolutionTab({required this.id, required this.accent, super.key});

  /// National Dex id used to resolve the chain provider.
  final int id;

  /// Section-title color — the primary type's badge color (RN-04). The host
  /// screen owns the lookup so all three tabs share one resolution.
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pokemonEvolutionProvider(id));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolution Chart',
            style: AppTypography.filterTitle.copyWith(color: accent),
          ),
          const SizedBox(height: 20),
          async.when(
            skipLoadingOnReload: true,
            data: (chain) {
              final pairs = _flattenPairs(chain.root);
              if (pairs.isEmpty) {
                return const Text(
                  'This Pokémon does not evolve.',
                  style: AppTypography.description,
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < pairs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 20),
                    _EvolutionRow(
                      parent: pairs[i].$1,
                      child: pairs[i].$2,
                    ),
                  ],
                ],
              );
            },
            loading: () => const _EvolutionSkeleton(),
            error: (_, _) => const Text(
              'Could not load the evolution chain.',
              style: AppTypography.description,
            ),
          ),
        ],
      ),
    );
  }

  /// Walks the chain depth-first, emitting one (parent stage, child node)
  /// pair per edge. The result is a flat list ordered so adjacent pairs share
  /// the same alignment (stage card | connector | stage card).
  static List<(EvolutionStage, EvolutionNode)> _flattenPairs(
    EvolutionNode root,
  ) {
    final pairs = <(EvolutionStage, EvolutionNode)>[];
    void walk(EvolutionNode node) {
      for (final next in node.evolvesTo) {
        pairs.add((node.stage, next));
        walk(next);
      }
    }

    walk(root);
    return pairs;
  }
}

/// A single `parent → child` evolution row. Both stage cards lock to a fixed
/// width while the connector flexes — so the layout adapts to the available
/// width without ever shifting the cards off-axis between rows.
class _EvolutionRow extends StatelessWidget {
  const _EvolutionRow({required this.parent, required this.child});

  static const double _cardWidth = 100;

  final EvolutionStage parent;
  final EvolutionNode child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _cardWidth,
          child: _StageCard(stage: parent),
        ),
        Expanded(child: _Connector(condition: child.stage.condition)),
        SizedBox(
          width: _cardWidth,
          child: _StageCard(stage: child.stage),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.condition});

  final String? condition;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.arrow_forward,
          size: 25,
          color: AppColors.textGray,
        ),
        const SizedBox(height: 5),
        Text(
          condition == null ? '' : '($condition)',
          style: AppTypography.pokemonNumber.copyWith(
            color: AppColors.textBlack,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage});

  /// Pokéball silhouette diameter — matches the row's card slot width.
  static const double _backgroundSize = 100;

  /// Pokémon sprite size — deliberately larger than [_backgroundSize] so the
  /// sprite reads as "bigger than the card", echoing the list `PokemonCard`'s
  /// 130-on-115 sprite-overflows-body rhythm. The slot stays 100 wide so the
  /// row's connector still anchors between fixed-width columns; `Clip.none`
  /// just lets the sprite peek into the connector's whitespace.
  static const double _imageSize = 130;

  final EvolutionStage stage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/pokemon/${stage.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _backgroundSize,
            height: _backgroundSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ShaderMask paints a real top→bottom gradient onto the
                // pokéball silhouette. The asset's own white-on-white gradient
                // is invisible against the white tab panel, so we replace it
                // with a translucent gray ramp via `srcIn` — preserving the
                // ball's shape while making the gradient prominent.
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE5E5E5),
                      Color(0xFFFFFFFF),
                    ],
                  ).createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: SvgPicture.asset(
                    'assets/illustrations/pokeball.svg',
                    width: _backgroundSize,
                    height: _backgroundSize,
                  ),
                ),
                SizedBox(
                  width: _imageSize,
                  height: _imageSize,
                  child: _StageImage(imageUrl: stage.imageUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '#${stage.id.toString().padLeft(3, '0')}',
            style: AppTypography.pokemonNumber.copyWith(
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            StringUtils.capitalize(stage.name),
            style: AppTypography.filterTitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StageImage extends StatelessWidget {
  const _StageImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Icon(
        Icons.broken_image,
        color: AppColors.textGray,
        size: 36,
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) =>
          const Icon(Icons.broken_image, color: AppColors.textGray, size: 36),
    );
  }
}

class _EvolutionSkeleton extends StatelessWidget {
  const _EvolutionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 2; i++) ...[
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.backgroundInput,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ],
    );
  }
}
