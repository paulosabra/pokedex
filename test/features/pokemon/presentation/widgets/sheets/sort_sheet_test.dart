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

    testWidgets('drag-to-dismiss pops null', (tester) async {
      final handle = await _openSheet(
        tester,
        initial: SortCriteria.numberAsc,
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await handle.result, isNull);
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
