import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/states/offline_error_widget.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('OfflineErrorWidget', () {
    testWidgets('renders message and Retry button', (tester) async {
      await _pump(tester, OfflineErrorWidget(onRetry: () {}));

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Retry tap fires the callback', (tester) async {
      var taps = 0;
      await _pump(tester, OfflineErrorWidget(onRetry: () => taps++));

      await tester.tap(find.text('Retry'));

      expect(taps, 1);
    });

    testWidgets('renders the override message when provided', (tester) async {
      await _pump(
        tester,
        OfflineErrorWidget(message: 'custom copy', onRetry: () {}),
      );

      expect(find.text('custom copy'), findsOneWidget);
    });

    testWidgets('golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(tester, OfflineErrorWidget(onRetry: () {}));

      await expectLater(
        find.byType(OfflineErrorWidget),
        matchesGoldenFile('goldens/offline_error_widget.png'),
      );
    });
  });
}
