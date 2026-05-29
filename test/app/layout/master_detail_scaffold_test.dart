import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/layout/master_detail_scaffold.dart';

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  // Pin devicePixelRatio so physicalSize == logical (DIP) size — otherwise the
  // default test view DPR shrinks `MediaQuery.sizeOf(context).width`.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  group('MasterDetailScaffold', () {
    testWidgets('renders only the child panel on compact viewports', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        const Size(400, 800),
        MasterDetailScaffold(
          masterBuilder: (_) => const Text('master'),
          child: const Text('detail'),
        ),
      );

      expect(find.text('detail'), findsOneWidget);
      expect(find.text('master'), findsNothing);
    });

    testWidgets('renders only the child panel on medium viewports', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        const Size(800, 800),
        MasterDetailScaffold(
          masterBuilder: (_) => const Text('master'),
          child: const Text('detail'),
        ),
      );

      expect(find.text('detail'), findsOneWidget);
      expect(find.text('master'), findsNothing);
    });

    testWidgets('renders both panels side-by-side on expanded viewports', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        const Size(1300, 800),
        MasterDetailScaffold(
          masterBuilder: (_) => const Text('master'),
          child: const Text('detail'),
        ),
      );

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
      // Master + child composed in a Row.
      expect(find.byType(Row), findsOneWidget);
    });
  });
}
