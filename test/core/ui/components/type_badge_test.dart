import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/theme/pokemon_type_theme.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';

Future<void> _pumpBadge(
  WidgetTester tester, {
  required PokemonTypeId type,
  TypeBadgeSize size = TypeBadgeSize.small,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: TypeBadge(type: type, size: size),
        ),
      ),
    ),
  );
}

void main() {
  group('TypeBadge', () {
    testWidgets('renders the title-cased type label', (tester) async {
      await _pumpBadge(tester, type: PokemonTypeId.grass);

      expect(find.text('Grass'), findsOneWidget);
    });

    testWidgets('applies the PokemonTypeTheme color to the background', (
      tester,
    ) async {
      await _pumpBadge(tester, type: PokemonTypeId.fire);

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
        await _pumpBadge(tester, type: type);
        final expected =
            '${type.name[0].toUpperCase()}${type.name.substring(1)}';
        expect(find.text(expected), findsOneWidget);
      }
    });

    testWidgets('grows when sized medium', (tester) async {
      await _pumpBadge(tester, type: PokemonTypeId.water);
      final smallSize = tester.getSize(find.byType(TypeBadge));

      await _pumpBadge(
        tester,
        type: PokemonTypeId.water,
        size: TypeBadgeSize.medium,
      );
      final mediumSize = tester.getSize(find.byType(TypeBadge));

      expect(mediumSize.height, greaterThan(smallSize.height));
      expect(mediumSize.width, greaterThan(smallSize.width));
    });

    group('goldens', () {
      for (final type in [
        PokemonTypeId.grass,
        PokemonTypeId.fire,
        PokemonTypeId.water,
      ]) {
        testWidgets('${type.name} small', (tester) async {
          await _pumpBadge(tester, type: type);
          await expectLater(
            find.byType(TypeBadge),
            matchesGoldenFile('goldens/type_badge_${type.name}_small.png'),
          );
        });
      }

      testWidgets('grass medium', (tester) async {
        await _pumpBadge(
          tester,
          type: PokemonTypeId.grass,
          size: TypeBadgeSize.medium,
        );
        await expectLater(
          find.byType(TypeBadge),
          matchesGoldenFile('goldens/type_badge_grass_medium.png'),
        );
      });
    });
  });
}
