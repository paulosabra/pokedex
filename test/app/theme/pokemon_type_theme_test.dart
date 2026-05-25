import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

void main() {
  group('PokemonTypeTheme', () {
    testWidgets('colors a widget by its Pokémon type (RN-04)', (tester) async {
      await tester.pumpWidget(
        ColoredBox(color: PokemonTypeTheme.styleOf(PokemonTypeId.fire).color),
      );
      final fire = tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

      await tester.pumpWidget(
        ColoredBox(color: PokemonTypeTheme.styleOf(PokemonTypeId.water).color),
      );
      final water = tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

      expect(fire, const Color(0xFFFD7D24));
      expect(water, const Color(0xFF4A90DA));
      expect(fire, isNot(water));
    });

    test('resolves a unique badge color for all 18 types', () {
      final colors = {
        for (final type in PokemonTypeId.values)
          PokemonTypeTheme.styleOf(type).color,
      };

      expect(PokemonTypeId.values, hasLength(18));
      expect(colors, hasLength(18));
    });

    test('backgrounds: exact §10.3 for grass/fire, derived tint otherwise', () {
      expect(
        PokemonTypeTheme.styleOf(PokemonTypeId.grass).backgroundColor,
        const Color(0xFF8BBE8A),
      );
      expect(
        PokemonTypeTheme.styleOf(PokemonTypeId.fire).backgroundColor,
        const Color(0xFFFFA756),
      );

      // A derived background is the 50% midpoint between the badge color and
      // white — assert the formula per channel (independent of Color.lerp's
      // exact rounding), not just that it differs from the badge color.
      final water = PokemonTypeTheme.styleOf(PokemonTypeId.water);
      expect(water.backgroundColor.r, closeTo((water.color.r + 1.0) / 2, 0.01));
      expect(water.backgroundColor.g, closeTo((water.color.g + 1.0) / 2, 0.01));
      expect(water.backgroundColor.b, closeTo((water.color.b + 1.0) / 2, 0.01));
    });
  });
}
