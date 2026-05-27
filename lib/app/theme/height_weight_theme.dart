import 'package:flutter/material.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';

/// Per-bucket colors for the Filters sheet's Height and Weight sections,
/// matching the Figma `Height / *` and `Weight / *` symbols (Components page).
///
/// Centralizes the bucket palette so a future Figma tweak edits one file
/// instead of being scattered across widget literals — same role
/// [`PokemonTypeTheme`] plays for the type badges.
abstract final class HeightWeightTheme {
  const HeightWeightTheme._();

  static const Map<HeightCategory, Color> _heightColors = {
    HeightCategory.short: Color(0xFFFFC5E6),
    HeightCategory.medium: Color(0xFFAEBFD7),
    HeightCategory.tall: Color(0xFFAAACB8),
  };

  static const Map<WeightCategory, Color> _weightColors = {
    WeightCategory.light: Color(0xFF99CD7C),
    WeightCategory.normal: Color(0xFF57B2DC),
    WeightCategory.heavy: Color(0xFF5A92A5),
  };

  /// The Figma color for the Height bucket [category].
  static Color colorForHeight(HeightCategory category) =>
      _heightColors[category]!;

  /// The Figma color for the Weight bucket [category].
  static Color colorForWeight(WeightCategory category) =>
      _weightColors[category]!;
}
