import 'package:flutter/material.dart';
import 'package:pokedex/core/ui/states/state_view.dart';

/// Empty-state for the filter-only discovery path (TE-05).
///
/// Distinct from the search-empty variant (which renders the query verbatim)
/// and the generation-empty variant (which talks about incomplete data). Used
/// when one or more filter axes — types / weaknesses / heights / weights /
/// number range — are active but the cache has no rows that satisfy the
/// intersection.
class EmptyFilterWidget extends StatelessWidget {
  /// Creates an [EmptyFilterWidget].
  const EmptyFilterWidget({this.onClear, super.key});

  /// Optional clear-all-filters callback. When `null`, the CTA is omitted
  /// (callers may instead expose a clear control inside the filters sheet).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return StateView(
      glyph: Icons.tune,
      title: 'No matches',
      body:
          'No Pokémon match the current filters. '
          'Tweak the selection or reset to start over.',
      actionLabel: onClear == null ? null : 'Reset filters',
      onAction: onClear,
      actionStyle: StateActionStyle.secondary,
    );
  }
}
