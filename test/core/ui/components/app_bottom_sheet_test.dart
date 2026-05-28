import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';

Future<void> _pump(WidgetTester tester, Widget sheet) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: sheet)));
}

void main() {
  group('AppBottomSheet', () {
    testWidgets('renders the title and the child content', (tester) async {
      await _pump(
        tester,
        const AppBottomSheet(
          title: 'Filters',
          child: Text('content'),
        ),
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('omits the primary action when not provided', (tester) async {
      await _pump(
        tester,
        const AppBottomSheet(
          title: 'Sort',
          child: SizedBox.shrink(),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders the primary action when provided', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        AppBottomSheet(
          title: 'Filters',
          primaryAction: ElevatedButton(
            onPressed: () => tapped = true,
            child: const Text('Apply'),
          ),
          child: const SizedBox.shrink(),
        ),
      );

      await tester.tap(find.text('Apply'));

      expect(tapped, isTrue);
    });

    testWidgets('renders the trailing widget in the header', (tester) async {
      var cleared = false;
      await _pump(
        tester,
        AppBottomSheet(
          title: 'Filters',
          titleTrailing: TextButton(
            onPressed: () => cleared = true,
            child: const Text('Clear'),
          ),
          child: const SizedBox.shrink(),
        ),
      );

      await tester.tap(find.text('Clear'));

      expect(cleared, isTrue);
    });
  });
}
