import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// Empty-state for the partial-generation backfill case (RN-15).
///
/// Distinct from the empty-filter widget: this isn't "the filter excludes
/// everything" — it's "we know this generation exists but no rows have been
/// backfilled into the cache yet, so try refreshing to fetch them". Resolves
/// flow-analysis blocker 6.
class EmptyGenerationWidget extends StatelessWidget {
  /// Creates an [EmptyGenerationWidget].
  const EmptyGenerationWidget({
    required this.onRetry,
    this.generationLabel,
    super.key,
  });

  /// Optional human-readable label for the active generation (e.g. "Gen 1").
  /// When `null` the message uses the generic "this generation" wording.
  final String? generationLabel;

  /// Fires on the Retry CTA. Usually wired to the VM refresh, which asks the
  /// network for missing generation rows.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final label = generationLabel ?? 'this generation';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.refresh,
              size: 48,
              color: AppColors.textGray,
            ),
            const SizedBox(height: 16),
            Text(
              'Incomplete data for $label. Refresh to load missing Pokémon.',
              textAlign: TextAlign.center,
              style: AppTypography.description,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: AppColors.textWhite,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
