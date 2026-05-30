import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/ui/components/section_header.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

void main() {
  group('SectionHeader', () {
    testWidgets('renders only the title when no trailing is provided', (
      tester,
    ) async {
      await _pump(tester, const SectionHeader(title: 'Types'));

      expect(find.text('Types'), findsOneWidget);
    });

    testWidgets('renders the trailing widget when provided', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        SectionHeader(
          title: 'Types',
          trailing: TextButton(
            onPressed: () => taps++,
            child: const Text('Clear'),
          ),
        ),
      );

      await tester.tap(find.text('Clear'));

      expect(taps, 1);
    });

    testWidgets('golden', (tester) async {
      await _pump(
        tester,
        SectionHeader(
          title: 'Filters',
          trailing: TextButton(
            onPressed: () {},
            child: const Text('Clear'),
          ),
        ),
      );
      await expectLater(
        find.byType(SectionHeader),
        matchesGoldenFile('goldens/section_header_with_trailing.png'),
      );
    });
  });
}
