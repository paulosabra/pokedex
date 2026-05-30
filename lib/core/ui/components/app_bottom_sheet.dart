import 'package:flutter/material.dart';
import 'package:pokedex/app/layout/breakpoints.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// The shared shell for discovery sheets (Filters, Sort, Generations).
///
/// Adapts to the active [Breakpoint]:
///
/// - **compact**: a bottom sheet with a drag handle, rounded top corners and a
///   white background — Figma frames `268:63` / `268:176` / `268:248`.
/// - **medium / expanded**: a centered, max-width dialog card with rounded
///   corners on all sides and no drag handle — the dialog modality picked by
///   [`ResponsiveLayout.showSheetOrDialog`].
///
/// Stateless and presentational — the caller owns the sheet's data.
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

  /// Maximum width for the dialog variant (medium / expanded breakpoints).
  static const double _dialogMaxWidth = 480;

  @override
  Widget build(BuildContext context) {
    final isDialog = Breakpoint.of(context) != Breakpoint.compact;
    return isDialog ? _buildDialog(context) : _buildSheet(context);
  }

  Widget _buildSheet(BuildContext context) {
    return Material(
      color: AppColors.backgroundWhite,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 12, 40, 20),
          child: _Body(
            title: title,
            subtitle: subtitle,
            titleTrailing: titleTrailing,
            primaryAction: primaryAction,
            showDragHandle: true,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final maxWidth = viewport.width.clamp(0.0, _dialogMaxWidth);
    return Dialog(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: AppColors.backgroundWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          // Leave breathing room above/below the dialog on tall viewports so
          // tall sheets (e.g. Filters with every section open) stay scrollable.
          maxHeight: viewport.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
          child: _Body(
            title: title,
            subtitle: subtitle,
            titleTrailing: titleTrailing,
            primaryAction: primaryAction,
            showDragHandle: false,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The shared title + content + action layout used by both the sheet and the
/// dialog variant. Only the surrounding chrome (drag handle, rounding,
/// modality) differs between the two.
class _Body extends StatelessWidget {
  const _Body({
    required this.title,
    required this.subtitle,
    required this.titleTrailing,
    required this.primaryAction,
    required this.showDragHandle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? titleTrailing;
  final Widget? primaryAction;
  final bool showDragHandle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDragHandle) ...[
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
        ],
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
    );
  }
}
