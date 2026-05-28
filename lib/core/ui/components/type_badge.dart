import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

/// A single Pokémon type pill: a 15×15 white type icon and the type name on a
/// type-colored 25-tall background — Figma `Badge / *` (3px radius, 5px
/// padding, 5px gap, 12pt Medium label).
///
/// Lives under `core/ui/` and takes a primitive [PokemonTypeId] — no imports
/// from `features/pokemon/domain/`.
class TypeBadge extends StatelessWidget {
  /// Creates a label-and-icon [TypeBadge] for the given [type] — the pill used
  /// on cards and the detail header.
  const TypeBadge({required this.type, super.key}) : iconOnly = false;

  /// Creates a square icon-only [TypeBadge] — Figma `Profile #1 - About` and
  /// `Profile #1 - Stats` Weaknesses / Type Defenses (4px radius, 6px padding,
  /// 18×18 white icon on a type-colored 30×30 tile).
  const TypeBadge.iconOnly({required this.type, super.key}) : iconOnly = true;

  /// The type whose color, icon, and label drive the badge.
  final PokemonTypeId type;

  /// `true` for the square icon-only variant (Weaknesses / Type Defenses);
  /// `false` for the labelled pill (cards / header).
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final style = PokemonTypeTheme.styleOf(type);
    return iconOnly ? _buildIconTile(style.color) : _buildPill(style.color);
  }

  Widget _buildPill(Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/types/${type.name}.svg',
              width: 15,
              height: 15,
              colorFilter: const ColorFilter.mode(
                AppColors.textWhite,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            Text(_labelFor(type), style: AppTypography.pokemonType),
          ],
        ),
      ),
    );
  }

  Widget _buildIconTile(Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/types/${type.name}.svg',
          width: 18,
          height: 18,
          colorFilter: const ColorFilter.mode(
            AppColors.textWhite,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  /// Title-cases the enum constant name (e.g., `grass` → `Grass`).
  String _labelFor(PokemonTypeId type) {
    final name = type.name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }
}
