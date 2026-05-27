import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// Visual style of the primary action button on a [StateView].
enum StateActionStyle {
  /// Red filled button with a drop shadow — matches the sheet system's
  /// `Apply` CTA (Figma `Filters - Scrolled`). Used for retry / refresh.
  primary,

  /// Flat grey button — matches the sheet system's `Reset` CTA. Used for
  /// destructive-but-recoverable affordances like "Clear search".
  secondary,
}

/// Branded empty / error scaffold (TE-01..TE-09 surfaces).
///
/// Renders a tinted pokeball illustration with a small foreground glyph,
/// a bold title and supporting copy, plus an optional action button styled
/// to match the sheet system. Every empty / error state in the app composes
/// against this shell so the visual language stays consistent with the Figma
/// mocks even though the file ships no empty-state frames of its own.
class StateView extends StatelessWidget {
  /// Creates a [StateView].
  const StateView({
    required this.title,
    required this.body,
    required this.glyph,
    this.actionLabel,
    this.onAction,
    this.actionStyle = StateActionStyle.primary,
    super.key,
  });

  /// Section title — bold 26pt, centered.
  final String title;

  /// Supporting copy — 16pt regular, centered, multi-line allowed.
  final String body;

  /// Foreground Material icon overlaid on the pokeball illustration. Keeps
  /// states distinguishable at a glance (search vs filter vs offline).
  final IconData glyph;

  /// Optional CTA label. Omit (with [onAction]) to render an information-only
  /// state with no button.
  final String? actionLabel;

  /// Fires on the CTA tap.
  final VoidCallback? onAction;

  /// Selects between the red primary and grey secondary button styling.
  final StateActionStyle actionStyle;

  @override
  Widget build(BuildContext context) {
    final showAction = actionLabel != null && onAction != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Hero(glyph: glyph),
            const SizedBox(height: 28),
            Text(
              title,
              style: AppTypography.sheetTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: AppTypography.description,
              textAlign: TextAlign.center,
            ),
            if (showAction) ...[
              const SizedBox(height: 28),
              _ActionButton(
                label: actionLabel!,
                onPressed: onAction!,
                style: actionStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Faded pokeball backdrop with a colored foreground glyph stacked on top.
///
/// The pokeball SVG is tinted in [`AppColors.backgroundInput`] so the
/// illustration reads as a soft, branded watermark instead of a hard
/// black silhouette. The glyph picks up [`AppColors.actionPrimary`] so it
/// stays visible against the tint.
class _Hero extends StatelessWidget {
  const _Hero({required this.glyph});

  final IconData glyph;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Icon(glyph, size: 56, color: AppColors.actionPrimary),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final VoidCallback onPressed;
  final StateActionStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: 220,
      child: switch (style) {
        StateActionStyle.primary => ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.actionPrimary,
            foregroundColor: AppColors.textWhite,
            elevation: 10,
            shadowColor: AppColors.actionPrimary.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(label),
        ),
        StateActionStyle.secondary => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.backgroundInput,
            foregroundColor: AppColors.textGray,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(label),
        ),
      },
    );
  }
}
