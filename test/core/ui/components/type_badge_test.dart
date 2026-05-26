import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';

Future<void> _pumpBadge(WidgetTester tester, PokemonTypeId type) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: TypeBadge(type: type)),
      ),
    ),
  );
}

void main() {
  group('TypeBadge', () {
    testWidgets('renders the title-cased type label', (tester) async {
      await _pumpBadge(tester, PokemonTypeId.grass);

      expect(find.text('Grass'), findsOneWidget);
    });

    testWidgets('renders the type icon', (tester) async {
      await _pumpBadge(tester, PokemonTypeId.grass);

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('applies the PokemonTypeTheme color to the background', (
      tester,
    ) async {
      await _pumpBadge(tester, PokemonTypeId.fire);

      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(TypeBadge),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decorated.decoration as BoxDecoration;

      expect(
        decoration.color,
        PokemonTypeTheme.styleOf(PokemonTypeId.fire).color,
      );
    });

    testWidgets('labels every one of the 18 types without crashing', (
      tester,
    ) async {
      for (final type in PokemonTypeId.values) {
        await _pumpBadge(tester, type);
        final expected =
            '${type.name[0].toUpperCase()}${type.name.substring(1)}';
        expect(find.text(expected), findsOneWidget);
      }
    });

    group('goldens', () {
      for (final type in [
        PokemonTypeId.grass,
        PokemonTypeId.fire,
        PokemonTypeId.water,
      ]) {
        testWidgets(type.name, (tester) async {
          await _pumpBadge(tester, type);
          await expectLater(
            find.byType(TypeBadge),
            matchesGoldenFile('goldens/type_badge_${type.name}.png'),
          );
        });
      }
    });
  });
}
