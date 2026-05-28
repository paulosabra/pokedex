import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/states/empty_search_widget.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('EmptySearchWidget', () {
    testWidgets('renders the query verbatim in the message', (tester) async {
      await _pump(tester, const EmptySearchWidget(query: 'zzzz'));

      // The widget shows a static title ("No Pokémon found") and a body that
      // embeds the query verbatim so the user sees what was searched.
      expect(
        find.textContaining('"zzzz"'),
        findsOneWidget,
      );
    });

    testWidgets('omits the clear CTA when onClear is null', (tester) async {
      await _pump(tester, const EmptySearchWidget(query: 'q'));

      expect(find.text('Clear search'), findsNothing);
    });

    testWidgets('renders the clear CTA and fires the callback', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        EmptySearchWidget(query: 'q', onClear: () => taps++),
      );

      await tester.tap(find.text('Clear search'));

      expect(taps, 1);
    });

    testWidgets('golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(
        tester,
        EmptySearchWidget(query: 'mewthree', onClear: () {}),
      );

      await expectLater(
        find.byType(EmptySearchWidget),
        matchesGoldenFile('goldens/empty_search_widget.png'),
      );
    });
  });
}
