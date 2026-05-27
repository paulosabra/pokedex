import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';
import 'package:pokedex/core/utils/string_utils.dart';

/// The colored detail-screen header — Figma `Profile #2 - About` (`321:416`).
///
/// Renders the back-button row, the watermark species name, the artwork-in-
/// circle on the left, the dot-pattern decoration in the top-right, and the
/// number/name/badges stack. Lives directly under the screen's tinted
/// background (the [Scaffold]'s `backgroundColor` is the type background
/// tint, so this widget only paints its content).
class DetailHeader extends StatelessWidget {
  /// Creates a [DetailHeader].
  const DetailHeader({
    required this.id,
    required this.name,
    required this.primaryType,
    required this.secondaryType,
    required this.imageUrl,
    required this.onBack,
    super.key,
  });

  static const double _height = 285;

  /// National Dex id, rendered as `#NNN` (RF-02).
  final int id;

  /// Display name (capitalized when rendered).
  final String name;

  /// Drives the badge color and the screen background tint (RN-04).
  final PokemonTypeId primaryType;

  /// Optional secondary type, rendered as a second badge if present.
  final PokemonTypeId? secondaryType;

  /// Official artwork URL. Renders the TE-11 placeholder when empty or when
  /// the network fetch fails.
  final String imageUrl;

  /// Back-button callback — typically `() => context.pop()` (falls back to
  /// `context.go('/')` if the route was deep-linked into).
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryType;
    return SizedBox(
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Watermark species name — Figma renders this as a transparent
          // gradient stroke at 100pt. Approximated with low-opacity white
          // bold text so the silhouette is preserved without depending on a
          // shader.
          Positioned(
            top: 15,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                name.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 100,
                  fontWeight: FontWeight.w700,
                  color: Color(0x40FFFFFF),
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ),
          const Positioned(
            top: 40,
            right: 25,
            width: 126,
            height: 82,
            child: _DotPattern(),
          ),
          Positioned(
            left: 40,
            top: 30,
            child: _BackButton(onTap: onBack),
          ),
          Positioned(
            left: 40,
            top: 85,
            width: 125,
            height: 125,
            child: _ArtworkInCircle(imageUrl: imageUrl),
          ),
          Positioned(
            left: 190,
            top: 104,
            child: Text(
              '#${id.toString().padLeft(3, '0')}',
              style: AppTypography.filterTitle.copyWith(
                color: AppColors.textNumber,
              ),
            ),
          ),
          Positioned(
            left: 190,
            top: 123,
            right: 16,
            child: Text(
              StringUtils.capitalize(name),
              style: AppTypography.pokemonName.copyWith(
                fontSize: 32,
                color: AppColors.textWhite,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            left: 190,
            top: 166,
            right: 16,
            child: Wrap(
              spacing: 6,
              children: [
                TypeBadge(type: primaryType),
                if (secondary != null) TypeBadge(type: secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: const SizedBox(
          width: 25,
          height: 25,
          child: Icon(Icons.arrow_back, color: AppColors.textWhite, size: 25),
        ),
      ),
    );
  }
}

class _ArtworkInCircle extends StatelessWidget {
  const _ArtworkInCircle({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned.fill(child: _Artwork(imageUrl: imageUrl)),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const _ArtworkPlaceholder();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (_, _) => const _ArtworkLoading(),
      errorWidget: (_, _, _) => const _ArtworkPlaceholder(),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image, color: AppColors.textWhite, size: 56),
    );
  }
}

class _ArtworkLoading extends StatelessWidget {
  const _ArtworkLoading();

  @override
  Widget build(BuildContext context) {
    // Static placeholder — no spinner — so widget tests can `pumpAndSettle`
    // without trapping on an infinite animation while CachedNetworkImage
    // resolves the artwork.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite.withValues(alpha: 0.15),
        shape: BoxShape.circle,
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
