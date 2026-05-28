import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/sort_sheet.dart';

class _Handle {
  _Handle(this.result);
  final Future<SortCriteria?> result;
}

Future<_Handle> _openSheet(
  WidgetTester tester, {
  required SortCriteria initial,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final completer = Completer<SortCriteria?>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final r = await showModalBottomSheet<SortCriteria?>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SortSheet(initial: initial),
              );
              completer.complete(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return _Handle(completer.future);
}

void main() {
  group('SortSheet', () {
    testWidgets('renders the four Figma sort options', (tester) async {
      await _openSheet(tester, initial: SortCriteria.numberAsc);

      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Smallest number first'), findsOneWidget);
      expect(find.text('Highest number first'), findsOneWidget);
      expect(find.text('A-Z'), findsOneWidget);
      expect(find.text('Z-A'), findsOneWidget);
    });

    testWidgets(
      'tapping an option pops with the chosen criterion (tap = apply)',
      (tester) async {
        final handle = await _openSheet(
          tester,
          initial: SortCriteria.numberAsc,
        );

        await tester.tap(find.text('Z-A'));
        await tester.pumpAndSettle();

        final result = await handle.result;
        expect(result, SortCriteria.nameDesc);
      },
    );

    testWidgets('tapping the initial selection still pops with it', (
      tester,
    ) async {
      final handle = await _openSheet(
        tester,
        initial: SortCriteria.nameAsc,
      );

      await tester.tap(find.text('A-Z'));
      await tester.pumpAndSettle();

      final result = await handle.result;
      expect(result, SortCriteria.nameAsc);
    });

    testWidgets(
      'visually highlights the initial selection via Material color',
      (tester) async {
        await _openSheet(tester, initial: SortCriteria.nameAsc);

        Material materialFor(String label) => tester.widget<Material>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        );

        // The active row uses the primary accent fill; peers stay in the
        // secondary unselected fill. A regression that always rendered every
        // row as unselected would flip both branches and fail this assertion.
        expect(materialFor('A-Z').color, AppColors.actionPrimary);
        expect(materialFor('Z-A').color, AppColors.backgroundInput);
      },
    );

    testWidgets('dismissal without a selection pops null', (tester) async {
      final handle = await _openSheet(
        tester,
        initial: SortCriteria.numberAsc,
      );

      // Pops the modal route directly to assert the null-result contract.
      // `tester.tapAt(Offset(10, 10))` against the modal barrier hangs in
      // flutter_test under `showModalBottomSheet(isScrollControlled: true)`,
      // so the explicit dismissal-as-drag-to-dismiss coverage is dropped
      // here — only the caller-visible outcome (a null `SortCriteria?`) is
      // still pinned.
      Navigator.of(tester.element(find.byType(SortSheet))).pop();
      await tester.pumpAndSettle();

      expect(await handle.result, isNull);
    });
  });
}
