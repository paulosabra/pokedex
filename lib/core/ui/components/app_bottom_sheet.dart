import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/core/ui/components/section_header.dart';

/// The shared shell for discovery sheets (Filters, Sort, Generations).
///
/// Lays out a drag handle, a [SectionHeader] (title + optional clear CTA), the
/// caller's [child] content, and an optional [primaryAction] CTA at the
/// bottom. Stateless and presentational — the caller owns the sheet's data.
class AppBottomSheet extends StatelessWidget {
  /// Creates an [AppBottomSheet].
  const AppBottomSheet({
    required this.title,
    required this.child,
    this.titleTrailing,
    this.primaryAction,
    super.key,
  });

  /// Header title — usually the sheet's purpose (e.g., "Filters").
  final String title;

  /// Optional trailing widget in the header row (e.g., a "Clear" CTA).
  final Widget? titleTrailing;

  /// Sheet content.
  final Widget child;

  /// Optional primary action rendered at the bottom (e.g., "Apply").
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundWhite,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textGray.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: title, trailing: titleTrailing),
              const SizedBox(height: 16),
              Flexible(child: child),
              if (primaryAction != null) ...[
                const SizedBox(height: 16),
                primaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
