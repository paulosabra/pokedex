import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/layout/breakpoints.dart';
import 'package:pokedex/app/layout/responsive_layout.dart';

void main() {
  group('ResponsiveLayout.gridColumns', () {
    test('compact → 1 column', () {
      expect(ResponsiveLayout.gridColumns(Breakpoint.compact), 1);
    });

    test('medium → 2 columns', () {
      expect(ResponsiveLayout.gridColumns(Breakpoint.medium), 2);
    });

    test('expanded → 3 columns', () {
      expect(ResponsiveLayout.gridColumns(Breakpoint.expanded), 3);
    });
  });

  group('ResponsiveLayout.showSheetOrDialog', () {
    testWidgets('renders a bottom sheet on compact viewports', (tester) async {
      await _setLogicalSize(tester, const Size(400, 800));

      final anchor = await _pumpAnchor(tester);
      _openModal(anchor);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(_Sentinel), findsOneWidget);
    });

    testWidgets('renders a dialog on medium viewports', (tester) async {
      await _setLogicalSize(tester, const Size(800, 800));

      final anchor = await _pumpAnchor(tester);
      _openModal(anchor);
      await tester.pumpAndSettle();

      // showDialog doesn't auto-wrap content in a `Dialog`; the contract is
      // "no BottomSheet was opened and the modal content is mounted".
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(_Sentinel), findsOneWidget);
    });

    testWidgets(
      'renders a dialog on expanded viewports (≥ 1024 logical px)',
      (tester) async {
        await _setLogicalSize(tester, const Size(1300, 900));

        final anchor = await _pumpAnchor(tester);
        _openModal(anchor);
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(_Sentinel), findsOneWidget);
      },
    );

    testWidgets(
      'breakpoint is sampled at invocation, not via a reactive listener '
      '(resolved blocker 8)',
      (tester) async {
        await _setLogicalSize(tester, const Size(400, 800));

        final anchor = await _pumpAnchor(tester);
        _openModal(anchor);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);

        // Resize past the medium threshold while the sheet is open. The open
        // modal stays a sheet — no reactive switch to a dialog.
        await _setLogicalSize(tester, const Size(1100, 800));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
      },
    );
  });
}

/// Sets a logical (DIP) viewport size by pinning the test view's
/// devicePixelRatio to 1 — otherwise `setSurfaceSize` sets *physical* pixels
/// and the default test DPR (3.0) shrinks the logical width.
Future<void> _setLogicalSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<BuildContext> _pumpAnchor(WidgetTester tester) async {
  late BuildContext anchor;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            anchor = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return anchor;
}

void _openModal(BuildContext context) {
  ResponsiveLayout.showSheetOrDialog<void>(
    context: context,
    builder: (_) => const _Sentinel(),
  ).ignore();
}

class _Sentinel extends StatelessWidget {
  const _Sentinel();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 1, height: 1);
}
