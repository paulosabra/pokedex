import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/components/stat_bar.dart';

const _fireColor = Color(0xFFFD7D24);

Future<void> _pumpBar(
  WidgetTester tester, {
  required int value,
  int max = 255,
  Color color = _fireColor,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: StatBar(label: 'HP', value: value, max: max, color: color),
        ),
      ),
    ),
  );
}

void main() {
  group('StatBar', () {
    testWidgets('renders the label and the value as text', (tester) async {
      await _pumpBar(tester, value: 50);

      expect(find.text('HP'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('paints the fill at width = value / max', (tester) async {
      await _pumpBar(tester, value: 128);

      final fraction = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );

      expect(fraction.widthFactor, closeTo(128 / 255, 1e-9));
    });

    testWidgets('clamps a value above max to 100%', (tester) async {
      await _pumpBar(tester, value: 999);

      final fraction = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );

      expect(fraction.widthFactor, 1.0);
    });

    testWidgets('clamps a negative value to 0%', (tester) async {
      await _pumpBar(tester, value: -10);

      final fraction = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );

      expect(fraction.widthFactor, 0.0);
    });

    group('goldens', () {
      for (final value in const [0, 50, 100, 255]) {
        testWidgets('value $value', (tester) async {
          await _pumpBar(tester, value: value);
          await expectLater(
            find.byType(StatBar),
            matchesGoldenFile('goldens/stat_bar_$value.png'),
          );
        });
      }
    });
  });
}
