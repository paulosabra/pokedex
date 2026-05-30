import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_typography.dart';

/// A section title row used in sheets and detail tabs.
///
/// Renders [title] using [AppTypography.filterTitle] and an optional
/// [trailing] widget (e.g. a "Clear" CTA in a filter sheet).
class SectionHeader extends StatelessWidget {
  /// Creates a [SectionHeader].
  const SectionHeader({required this.title, this.trailing, super.key});

  /// Title text rendered on the leading side.
  final String title;

  /// Optional trailing widget; usually a [TextButton] or [IconButton].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.filterTitle)),
        ?trailing,
      ],
    );
  }
}
