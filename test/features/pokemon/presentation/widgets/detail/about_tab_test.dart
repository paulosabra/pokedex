import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/about_tab.dart';

import '../../fixtures/pokemon_detail_builder.dart';

Future<void> _pump(WidgetTester tester, PokemonDetail detail) async {
  await tester.binding.setSurfaceSize(const Size(414, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AboutTab(detail: detail, accent: const Color(0xFF62B957)),
      ),
    ),
  );
}

void main() {
  group('AboutTab', () {
    testWidgets('renders the four entity sections', (tester) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('Pokédex Data'), findsOneWidget);
      expect(find.text('Training'), findsOneWidget);
      expect(find.text('Breeding'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('renders Pokédex Data rows with formatted height + weight', (
      tester,
    ) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('Species'), findsOneWidget);
      expect(find.text('Seed Pokémon'), findsOneWidget);
      // Height with imperial conversion (0.7m ≈ 2′4″)
      expect(find.text('0.7m (2′4″)'), findsOneWidget);
      // Weight with imperial conversion (6.9kg ≈ 15.2 lbs)
      expect(find.text('6.9kg (15.2 lbs)'), findsOneWidget);
    });

    testWidgets('renders the regular ability with index + the hidden ability', (
      tester,
    ) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('1. Overgrow'), findsOneWidget);
      expect(find.text('Chlorophyll (hidden ability)'), findsOneWidget);
    });

    testWidgets(
      'TE-10 — renders — for missing string fields',
      (tester) async {
        final detail = bulbasaurDetail().copyWith(
          genus: '',
          training: bulbasaurDetail().training.copyWith(
            evYield: '',
            growthRate: '',
            baseExp: null,
          ),
        );
        await _pump(tester, detail);
        await tester.pumpAndSettle();

        // Genus dash, evYield dash, growthRate dash, baseExp dash.
        expect(find.text('—'), findsNWidgets(4));
      },
    );

    testWidgets('omits the Location section when locations are empty', (
      tester,
    ) async {
      final detail = bulbasaurDetail().copyWith(locations: const []);
      await _pump(tester, detail);
      await tester.pumpAndSettle();

      expect(find.text('Location'), findsNothing);
    });

    testWidgets('golden — AboutTab for Bulbasaur', (tester) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AboutTab),
        matchesGoldenFile('goldens/about_tab.png'),
      );
    });
  });
}
