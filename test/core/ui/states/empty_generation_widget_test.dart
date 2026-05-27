import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/states/empty_generation_widget.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('EmptyGenerationWidget', () {
    testWidgets('renders the generic message when no label is given', (
      tester,
    ) async {
      await _pump(tester, EmptyGenerationWidget(onRetry: () {}));

      expect(
        find.text(
          'Incomplete data for this generation. '
          'Refresh to load missing Pokémon.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('embeds the supplied generation label in the message', (
      tester,
    ) async {
      await _pump(
        tester,
        EmptyGenerationWidget(generationLabel: 'Gen 3', onRetry: () {}),
      );

      expect(
        find.text(
          'Incomplete data for Gen 3. Refresh to load missing Pokémon.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Retry tap fires the callback', (tester) async {
      var taps = 0;
      await _pump(tester, EmptyGenerationWidget(onRetry: () => taps++));

      await tester.tap(find.text('Retry'));

      expect(taps, 1);
    });

    testWidgets('golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(
        tester,
        EmptyGenerationWidget(generationLabel: 'Gen 1', onRetry: () {}),
      );

      await expectLater(
        find.byType(EmptyGenerationWidget),
        matchesGoldenFile('goldens/empty_generation_widget.png'),
      );
    });
  });
}
