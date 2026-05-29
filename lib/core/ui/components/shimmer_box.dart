import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// Animated shimmer wrapper for skeleton placeholders (TE-12 loading state).
///
/// Pairs the existing `backgroundInput` token with a brighter highlight so the
/// sweep reads on the white surfaces used by the list/detail screens. Compose
/// any opaque child — typically one or more [SkeletonBox]es — and the shimmer
/// animates across all of them at once.
class AppShimmer extends StatelessWidget {
  /// Creates an [AppShimmer] that animates across [child].
  const AppShimmer({required this.child, super.key});

  /// The opaque content the shimmer sweep is painted over.
  final Widget child;

  static const Color _base = AppColors.backgroundInput;
  static const Color _highlight = Color(0xFFFAFAFA);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base,
      highlightColor: _highlight,
      child: child,
    );
  }
}

/// A solid rounded rectangle — the canonical placeholder body used inside
/// [AppShimmer]. The fill color is incidental (the shimmer paints over it),
/// but is kept opaque so the box reads as a static skeleton when rendered
/// outside an [AppShimmer].
class SkeletonBox extends StatelessWidget {
  /// Creates a [SkeletonBox].
  const SkeletonBox({
    this.width,
    this.height,
    this.borderRadius = 10,
    super.key,
  });

  /// Optional fixed width; otherwise expands horizontally.
  final double? width;

  /// Optional fixed height; otherwise expands vertically.
  final double? height;

  /// Corner radius in logical pixels — 10 matches the project's card radius.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.backgroundInput,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
