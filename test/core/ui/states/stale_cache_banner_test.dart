import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/states/stale_cache_banner.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('StaleCacheBanner', () {
    testWidgets('renders the default message', (tester) async {
      await _pump(tester, const StaleCacheBanner());

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(
        find.text("You're offline — showing saved data."),
        findsOneWidget,
      );
    });

    testWidgets('renders the override message when provided', (tester) async {
      await _pump(tester, const StaleCacheBanner(message: 'custom banner'));

      expect(find.text('custom banner'), findsOneWidget);
    });

    testWidgets('golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 60));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(tester, const StaleCacheBanner());

      await expectLater(
        find.byType(StaleCacheBanner),
        matchesGoldenFile('goldens/stale_cache_banner.png'),
      );
    });
  });
}
