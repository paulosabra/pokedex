import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';

/// List-card component for a single Pokémon (RF-01..RF-04).
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

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatNumber(id), style: AppTypography.pokemonNumber),
                  const SizedBox(height: 4),
                  Text(
                    _capitalize(name),
                    style: AppTypography.pokemonName.copyWith(
                      color: AppColors.textWhite,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TypeBadge(type: primaryType),
                      if (secondary != null) TypeBadge(type: secondary),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 72,
              height: 72,
              child: _CardImage(imageUrl: imageUrl),
            ),
          ],
        ),
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
