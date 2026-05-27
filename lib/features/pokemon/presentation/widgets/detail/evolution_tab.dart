import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// call is slower). Renders the recursive [_EvolutionBranch] so branching
/// chains (e.g. Eevee) lay out faithfully (RN-13 / resolved blocker 5).
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
            data: (chain) => chain.root.evolvesTo.isEmpty
                ? const Text(
                    'This Pokémon does not evolve.',
                    style: AppTypography.description,
                  )
                : _EvolutionBranch(node: chain.root),
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
}

class _EvolutionBranch extends StatelessWidget {
  const _EvolutionBranch({required this.node});

  final EvolutionNode node;

  @override
  Widget build(BuildContext context) {
    if (node.evolvesTo.isEmpty) {
      return _StageCard(stage: node.stage);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in node.evolvesTo)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _Pair(
              parent: node.stage,
              child: child,
              showParent: child == node.evolvesTo.first,
            ),
          ),
      ],
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.parent,
    required this.child,
    required this.showParent,
  });

  final EvolutionStage parent;
  final EvolutionNode child;

  /// Suppresses the parent card on subsequent branches so a branching node
  /// (e.g. Eevee → Vaporeon/Jolteon/Flareon) shows the parent only once with
  /// a stack of children to the right.
  final bool showParent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 100,
              child: showParent
                  ? _StageCard(stage: parent)
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _Connector(condition: child.stage.condition),
            ),
            SizedBox(width: 100, child: _StageCard(stage: child.stage)),
          ],
        ),
        // Recurse into grandchildren of this branch.
        if (child.evolvesTo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 117),
            child: _EvolutionBranch(node: child),
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

  final EvolutionStage stage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/pokemon/${stage.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.backgroundInput,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _StageImage(imageUrl: stage.imageUrl),
              ),
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
