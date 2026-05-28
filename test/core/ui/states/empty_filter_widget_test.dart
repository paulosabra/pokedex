import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/states/empty_filter_widget.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('EmptyFilterWidget', () {
    testWidgets('renders the canonical message', (tester) async {
      await _pump(tester, const EmptyFilterWidget());

      // Body opens with the canonical "no matches" sentence — we assert on
      // the lead-in so copy tweaks past the first sentence don't break us.
      expect(
        find.textContaining('No Pokémon match the current filters.'),
        findsOneWidget,
      );
    });

    testWidgets('omits the clear CTA when onClear is null', (tester) async {
      await _pump(tester, const EmptyFilterWidget());

      expect(find.text('Reset filters'), findsNothing);
    });

    testWidgets('renders the clear CTA and fires the callback', (
      tester,
    ) async {
      var taps = 0;
      await _pump(tester, EmptyFilterWidget(onClear: () => taps++));

      await tester.tap(find.text('Reset filters'));

      expect(taps, 1);
    });

    testWidgets('golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(tester, EmptyFilterWidget(onClear: () {}));

      await expectLater(
        find.byType(EmptyFilterWidget),
        matchesGoldenFile('goldens/empty_filter_widget.png'),
      );
    });
  });
}
