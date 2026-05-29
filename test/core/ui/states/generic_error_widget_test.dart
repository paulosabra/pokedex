import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/states/generic_error_widget.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('GenericErrorWidget', () {
    testWidgets('renders the default message and Retry button', (
      tester,
    ) async {
      await _pump(tester, GenericErrorWidget(onRetry: () {}));

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders the override message when provided', (tester) async {
      await _pump(
        tester,
        GenericErrorWidget(message: 'specific message', onRetry: () {}),
      );

      expect(find.text('specific message'), findsOneWidget);
    });

    testWidgets('Retry tap fires the callback', (tester) async {
      var taps = 0;
      await _pump(tester, GenericErrorWidget(onRetry: () => taps++));

      await tester.tap(find.text('Retry'));

      expect(taps, 1);
    });
  });
}
