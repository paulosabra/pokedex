import 'package:flutter/material.dart';
import 'package:pokedex/core/ui/states/state_view.dart';

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
    return StateView(
      glyph: Icons.search_off,
      title: 'No Pokémon found',
      body:
          'We couldn’t find anything for "$query". '
          'Try a different name or National Pokédex number.',
      actionLabel: onClear == null ? null : 'Clear search',
      onAction: onClear,
      actionStyle: StateActionStyle.secondary,
    );
  }
}
