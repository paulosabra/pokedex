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
  });
}
