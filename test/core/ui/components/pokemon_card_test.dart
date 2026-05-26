import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/pokemon_card.dart';

Future<void> _pump(WidgetTester tester, Widget card) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: card),
      ),
    ),
  );
}

void main() {
  group('PokemonCard', () {
    testWidgets('renders #NNN, capitalized name, and the primary badge', (
      tester,
    ) async {
      await _pump(
        tester,
        const PokemonCard(
          id: 1,
          name: 'bulbasaur',
          primaryType: PokemonTypeId.grass,
        ),
      );

      expect(find.text('#001'), findsOneWidget);
      expect(find.text('Bulbasaur'), findsOneWidget);
      expect(find.text('Grass'), findsOneWidget);
    });

    testWidgets('renders the secondary badge when given two types', (
      tester,
    ) async {
      await _pump(
        tester,
        const PokemonCard(
          id: 1,
          name: 'bulbasaur',
          primaryType: PokemonTypeId.grass,
          secondaryType: PokemonTypeId.poison,
        ),
      );

      expect(find.text('Grass'), findsOneWidget);
      expect(find.text('Poison'), findsOneWidget);
    });

    testWidgets('renders no secondary badge when only one type is given', (
      tester,
    ) async {
      await _pump(
        tester,
        const PokemonCard(
          id: 4,
          name: 'charmander',
          primaryType: PokemonTypeId.fire,
        ),
      );

      expect(find.text('Fire'), findsOneWidget);
      expect(find.text('Poison'), findsNothing);
    });

    testWidgets('renders the broken-image placeholder when imageUrl is empty', (
      tester,
    ) async {
      await _pump(
        tester,
        const PokemonCard(
          id: 1,
          name: 'bulbasaur',
          primaryType: PokemonTypeId.grass,
        ),
      );

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
    });

    testWidgets(
      'errorWidget callback returns the broken-image placeholder (TE-11)',
      (tester) async {
        await _pump(
          tester,
          const PokemonCard(
            id: 1,
            name: 'bulbasaur',
            primaryType: PokemonTypeId.grass,
            imageUrl: 'https://example.invalid/x.png',
          ),
        );

        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        final context = tester.element(find.byType(CachedNetworkImage));
        final fallback = image.errorWidget!(context, 'url', 'boom');

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: fallback)));
        expect(find.byIcon(Icons.broken_image), findsOneWidget);
      },
    );

    testWidgets('fires onTap when tapped', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        PokemonCard(
          id: 1,
          name: 'bulbasaur',
          primaryType: PokemonTypeId.grass,
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(PokemonCard));

      expect(tapped, isTrue);
    });

    group('goldens', () {
      testWidgets('single-type card', (tester) async {
        await _pump(
          tester,
          const PokemonCard(
            id: 4,
            name: 'charmander',
            primaryType: PokemonTypeId.fire,
          ),
        );
        await expectLater(
          find.byType(PokemonCard),
          matchesGoldenFile('goldens/pokemon_card_single_type.png'),
        );
      });

      testWidgets('dual-type card', (tester) async {
        await _pump(
          tester,
          const PokemonCard(
            id: 1,
            name: 'bulbasaur',
            primaryType: PokemonTypeId.grass,
            secondaryType: PokemonTypeId.poison,
          ),
        );
        await expectLater(
          find.byType(PokemonCard),
          matchesGoldenFile('goldens/pokemon_card_dual_type.png'),
        );
      });

      testWidgets('placeholder image card', (tester) async {
        await _pump(
          tester,
          const PokemonCard(
            id: 25,
            name: 'pikachu',
            primaryType: PokemonTypeId.electric,
          ),
        );
        await expectLater(
          find.byType(PokemonCard),
          matchesGoldenFile('goldens/pokemon_card_placeholder.png'),
        );
      });
    });
  });
}
