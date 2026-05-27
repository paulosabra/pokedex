import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    testWidgets('renders the four sort options', (tester) async {
      await _openSheet(tester, initial: SortCriteria.numberAsc);

      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Number (ascending)'), findsOneWidget);
      expect(find.text('Number (descending)'), findsOneWidget);
      expect(find.text('Name (A → Z)'), findsOneWidget);
      expect(find.text('Name (Z → A)'), findsOneWidget);
    });

    testWidgets('initial option is rendered as selected (radio checked)', (
      tester,
    ) async {
      await _openSheet(tester, initial: SortCriteria.nameAsc);

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    });

    testWidgets('selecting an option and applying pops with that criterion', (
      tester,
    ) async {
      final handle = await _openSheet(
        tester,
        initial: SortCriteria.numberAsc,
      );

      await tester.tap(find.text('Name (Z → A)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await handle.result;
      expect(result, SortCriteria.nameDesc);
    });

    testWidgets('Apply without changing selection pops with the initial', (
      tester,
    ) async {
      final handle = await _openSheet(
        tester,
        initial: SortCriteria.nameAsc,
      );

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await handle.result;
      expect(result, SortCriteria.nameAsc);
    });

    testWidgets('golden', (tester) async {
      await _openSheet(tester, initial: SortCriteria.numberAsc);
      await expectLater(
        find.byType(SortSheet),
        matchesGoldenFile('goldens/sort_sheet.png'),
      );
    });
  });
}
