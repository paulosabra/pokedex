import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// Empty-state for the filter-only discovery path (TE-05).
///
/// Distinct from the search-empty variant (which renders the query verbatim)
/// and the generation-empty variant (which talks about incomplete data). Used
/// when one or more filter axes — types / weaknesses / heights / weights — are
/// active but the cache has no rows that satisfy the intersection.
class EmptyFilterWidget extends StatelessWidget {
  /// Creates an [EmptyFilterWidget].
  const EmptyFilterWidget({this.onClear, super.key});

  /// Optional clear-all-filters callback. When `null`, the CTA is omitted
  /// (callers may instead expose a clear control inside the filters sheet).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_alt_off,
              size: 48,
              color: AppColors.textGray,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Pokémon match the current filters.',
              textAlign: TextAlign.center,
              style: AppTypography.description,
            ),
            if (onClear != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
