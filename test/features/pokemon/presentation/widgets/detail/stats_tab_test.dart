import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/components/type_badge.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/stats_tab.dart';

import '../../fixtures/pokemon_detail_builder.dart';

Future<void> _pump(WidgetTester tester, PokemonDetail detail) async {
  await tester.binding.setSurfaceSize(const Size(414, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatsTab(detail: detail, accent: const Color(0xFF62B957)),
      ),
    ),
  );
}

void main() {
  group('StatsTab', () {
    testWidgets('renders the six stat rows + Total', (tester) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('HP'), findsOneWidget);
      expect(find.text('Attack'), findsOneWidget);
      expect(find.text('Defense'), findsOneWidget);
      expect(find.text('Sp. Atk'), findsOneWidget);
      expect(find.text('Sp. Def'), findsOneWidget);
      expect(find.text('Speed'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('renders Min/Max column headers on the Total row', (
      tester,
    ) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
    });

    testWidgets('computes Total as the sum of base stats', (tester) async {
      // Bulbasaur: 45+49+49+65+65+45 = 318
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('318'), findsOneWidget);
    });

    testWidgets('renders Type Defenses section with 18 badges', (tester) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('Type Defenses'), findsOneWidget);
      // 2 badges in the header + 18 in Type Defenses = 20 total. The header
      // is wrapped in DetailHeader (not pumped here), so the StatsTab only
      // renders the 18 defense badges.
      expect(find.byType(TypeBadge), findsNWidgets(18));
    });

    testWidgets('formats multipliers as fractions', (tester) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      expect(find.text('½'), findsOneWidget); // water = 0.5
      expect(find.text('2'), findsOneWidget); // fire = 2.0
      // Bug AND Poison are 0.0 — two matches.
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('golden — StatsTab for Bulbasaur', (tester) async {
      await _pump(tester, bulbasaurDetail());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(StatsTab),
        matchesGoldenFile('goldens/stats_tab.png'),
      );
    });
  });
}
