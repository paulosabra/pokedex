import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// The shared shell for discovery sheets (Filters, Sort, Generations).
///
/// Lays out a drag handle, a 26pt Bold [title] (with an optional
/// [titleTrailing] CTA), an optional 16pt Regular [subtitle], the [child], and
/// an optional [primaryAction] CTA at the bottom — matching Figma frames
/// `268:242` (Sort) and `268:314` (Generations). Stateless and presentational
/// — the caller owns the sheet's data.
class AppBottomSheet extends StatelessWidget {
  /// Creates an [AppBottomSheet].
  const AppBottomSheet({
    required this.title,
    required this.child,
    this.subtitle,
    this.titleTrailing,
    this.primaryAction,
    super.key,
  });

  /// Header title — usually the sheet's purpose (e.g., "Sort", "Generations").
  final String title;

  /// Optional supporting copy under the title, 16pt Regular #747476.
  final String? subtitle;

  /// Optional trailing widget in the header row (e.g., a "Clear" CTA).
  final Widget? titleTrailing;

  /// Sheet content.
  final Widget child;

  /// Optional primary action rendered at the bottom (e.g., "Apply").
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 12, 40, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.textGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text(title, style: AppTypography.sheetTitle)),
                ?titleTrailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(subtitle!, style: AppTypography.description),
            ],
            const SizedBox(height: 24),
            Flexible(child: child),
            if (primaryAction != null) ...[
              const SizedBox(height: 20),
              primaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}
