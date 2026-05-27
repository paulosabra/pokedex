import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';

/// List-card component for a single Pokémon (RF-01..RF-04).
///
/// Layout follows the Figma `Home` frame (`268:0`): a 115h type-tinted body
/// with a 95h white "shadow card" behind it (offset +20 inset, +10 y, blur 20,
/// 40% tint of the type background), the pokeball pattern overlay on the body,
/// the number/name/badges stacked on the left, and the 130×130 sprite on the
/// right overflowing 15px above the body.
///
/// Lives in the design system: takes primitive parameters only — never imports
/// from `features/pokemon/domain/`. The feature-side adapter is the one that
/// unpacks a `Pokemon` entity and routes the tap.
class PokemonCard extends StatelessWidget {
  /// Creates a [PokemonCard].
  const PokemonCard({
    required this.id,
    required this.name,
    required this.primaryType,
    this.secondaryType,
    this.imageUrl = '',
    this.onTap,
    super.key,
  });

  /// Total stack height — the 115h body plus the 15px sprite overflow above it.
  static const double height = 130;

  /// National Dex id, rendered as `#NNN` (RF-02).
  final int id;

  /// Display name (capitalized when shown).
  final String name;

  /// Drives the card's background tint (RN-04) and is rendered as a badge.
  final PokemonTypeId primaryType;

  /// Optional secondary type, rendered as a second badge after [primaryType].
  final PokemonTypeId? secondaryType;

  /// Sprite URL. When empty (or the network fetch fails) the card renders the
  /// TE-11 broken-image placeholder.
  final String imageUrl;

  /// Tap callback — usually `() => context.go('/pokemon/$id')` in the adapter.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = PokemonTypeTheme.styleOf(primaryType);
    final secondary = secondaryType;

    final card = SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 35,
            height: 95,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: style.backgroundColor.withValues(alpha: 0.4),
                    offset: const Offset(0, 10),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 15,
            height: 115,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: style.backgroundColor),
                  ),
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
          Positioned(
            left: 20,
            top: 35,
            right: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatNumber(id),
                  style: AppTypography.pokemonNumber.copyWith(
                    color: AppColors.textNumber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _capitalize(name),
                  style: AppTypography.pokemonName.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TypeBadge(type: primaryType),
                    if (secondary != null) TypeBadge(type: secondary),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: 130,
            height: 130,
            child: _CardImage(imageUrl: imageUrl),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: card,
      ),
    );
  }

  String _formatNumber(int id) => '#${id.toString().padLeft(3, '0')}';

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const _ImagePlaceholder();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image, color: AppColors.textWhite, size: 36),
    );
  }
}
