import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// Empty-state for the search/discovery query path (TE-04).
///
/// Renders the failed-to-match [query] in the message body and exposes an
/// optional [onClear] CTA that clears the search input in one tap.
class EmptySearchWidget extends StatelessWidget {
  /// Creates an [EmptySearchWidget].
  const EmptySearchWidget({required this.query, this.onClear, super.key});

  /// The query that returned no results. Always rendered verbatim in the
  /// message so the user can see what was searched.
  final String query;

  /// Optional clear-search callback. When `null`, the CTA is omitted (e.g. if
  /// the caller wants to render this widget in a layout that already exposes a
  /// clear button on the search field itself).
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
              Icons.search_off,
              size: 48,
              color: AppColors.textGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No Pokémon found for "$query".',
              textAlign: TextAlign.center,
              style: AppTypography.description,
            ),
            if (onClear != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
