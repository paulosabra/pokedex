import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// The colored detail-screen header — Figma `Profile #2 - About` (`321:416`).
///
/// Renders the back-button row, the dot-pattern decoration in the top-right
/// and the watermark species name centered behind them. The image, number,
/// name and badges from the prior PR were removed so the header reads as the
/// designer's intended "large name on tinted background" motif.
class DetailHeader extends StatelessWidget {
  /// Creates a [DetailHeader].
  const DetailHeader({
    required this.name,
    required this.onBack,
    super.key,
  });

  static const double _height = 140;

  /// Display name — rendered as the upper-case watermark behind the back row.
  final String name;

  /// Back-button callback — typically `() => context.pop()` (falls back to
  /// `context.go('/')` if the route was deep-linked into).
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Watermark species name — Figma renders this as a transparent
          // gradient stroke at 100pt. Approximated with low-opacity white
          // bold text so the silhouette is preserved without depending on a
          // shader. `FittedBox` with `scaleDown` keeps the 100pt designer
          // intent as an upper bound and only shrinks when the rendered name
          // would otherwise overflow the back-button gutter (long names like
          // "MR. MIME" on compact widths, or any name on narrower devices).
          Positioned(
            top: 15,
            left: 40,
            right: 40,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
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
                  softWrap: false,
                ),
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
