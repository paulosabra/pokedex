import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

/// Visual sizing for a [TypeBadge].
enum TypeBadgeSize {
  /// Compact badge used in list cards.
  small,

  /// Standard badge used in the detail header and sheets.
  medium,
}

/// A single Pokémon type pill: type name on a type-colored background.
///
/// The color comes from [PokemonTypeTheme], so adding a new type or recoloring
/// an existing one is a single-file change. Lives under `core/ui/` and takes a
/// primitive [PokemonTypeId] — no imports from `features/pokemon/domain/`.
class TypeBadge extends StatelessWidget {
  /// Creates a [TypeBadge] for the given [type].
  const TypeBadge({
    required this.type,
    this.size = TypeBadgeSize.small,
    super.key,
  });

  /// The type whose color and label drive the badge.
  final PokemonTypeId type;

  /// Visual sizing variant.
  final TypeBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final style = PokemonTypeTheme.styleOf(type);
    final metrics = _metricsFor(size);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(metrics.radius),
      ),
      child: Padding(
        padding: metrics.padding,
        child: Text(
          _labelFor(type),
          style: AppTypography.pokemonType.copyWith(fontSize: metrics.fontSize),
        ),
      ),
    );
  }

  _BadgeMetrics _metricsFor(TypeBadgeSize size) {
    switch (size) {
      case TypeBadgeSize.small:
        return const _BadgeMetrics(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          fontSize: 10,
          radius: 3,
        );
      case TypeBadgeSize.medium:
        return const _BadgeMetrics(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          fontSize: 12,
          radius: 4,
        );
    }
  }

  /// Title-cases the enum constant name (e.g., `grass` → `Grass`).
  String _labelFor(PokemonTypeId type) {
    final name = type.name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }
}

class _BadgeMetrics {
  const _BadgeMetrics({
    required this.padding,
    required this.fontSize,
    required this.radius,
  });

  final EdgeInsets padding;
  final double fontSize;
  final double radius;
}
