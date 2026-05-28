import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/ui/components/pokemon_card.dart' as core;
import 'package:pokedex/core/ui/components/shimmer_box.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';

/// Feature-side adapter for `core.PokemonCard`.
///
/// Takes a [Pokemon] domain entity, unpacks the primitive parameters the DS
/// component expects, and routes a tap to the detail screen. Keeps domain
/// imports out of `lib/core/ui/`.
///
/// Branches on `pokemon.types.isEmpty` — the convention used across the
/// index-aware search path: an entity with no types is a "skeleton" row
/// served from the index before its detail has hydrated. The skeleton card
/// keeps the list's visual rhythm (same height + layout) but replaces the
/// type-tinted body with a neutral surface and shimmer chips.
class PokemonCard extends StatelessWidget {
  /// Creates a [PokemonCard].
  const PokemonCard({required this.pokemon, this.compact = false, super.key});

  /// The Pokémon to render.
  final Pokemon pokemon;

  /// `true` to render the image-only variant on expanded breakpoints when the
  /// list panel sits beside an open detail panel. See
  /// [`core.PokemonCard.compact`].
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (pokemon.isSkeleton) {
      return _SkeletonPokemonCard(
        id: pokemon.id,
        name: pokemon.name,
        imageUrl: pokemon.imageUrl,
        compact: compact,
        onTap: () => context.go('/pokemon/${pokemon.id}'),
      );
    }
    final types = pokemon.types;
    return core.PokemonCard(
      id: pokemon.id,
      name: pokemon.name,
      primaryType: types.first,
      secondaryType: types.length > 1 ? types[1] : null,
      imageUrl: pokemon.imageUrl,
      compact: compact,
      onTap: () => context.go('/pokemon/${pokemon.id}'),
    );
  }
}

/// Skeleton-state list card for an index row without a hydrated summary.
/// Same dimensions as `core.PokemonCard` so the list never reflows when a
/// row upgrades from skeleton to hydrated.
class _SkeletonPokemonCard extends StatelessWidget {
  const _SkeletonPokemonCard({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.compact,
    required this.onTap,
  });

  final int id;
  final String name;
  final String imageUrl;
  final bool compact;
  final VoidCallback onTap;

  static const Color _bodyColor = AppColors.backgroundInput;

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      height: core.PokemonCard.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 15,
            height: 115,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: _bodyColor)),
                  Positioned.fill(
                    child: SvgPicture.asset(
                      'assets/illustrations/card_pattern.svg',
                      fit: BoxFit.cover,
                      alignment: Alignment.topLeft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!compact)
            Positioned(
              left: 20,
              top: 35,
              right: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#${id.toString().padLeft(3, '0')}',
                    style: AppTypography.pokemonNumber.copyWith(
                      color: AppColors.textNumber,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _capitalize(name),
                    style: AppTypography.pokemonName.copyWith(
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AppShimmer(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SkeletonBox(width: 56, height: 20),
                        SkeletonBox(width: 56, height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            right: compact ? null : 0,
            left: compact ? 0 : null,
            top: 0,
            width: compact ? null : 130,
            height: 130,
            child: compact
                ? Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 130,
                      height: 130,
                      child: _SkeletonImage(imageUrl: imageUrl),
                    ),
                  )
                : _SkeletonImage(imageUrl: imageUrl),
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: card,
      ),
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _SkeletonImage extends StatelessWidget {
  const _SkeletonImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.broken_image, color: AppColors.textGray, size: 36),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) => const Center(
        child: Icon(Icons.broken_image, color: AppColors.textGray, size: 36),
      ),
    );
  }
}
