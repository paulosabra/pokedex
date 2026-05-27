import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/generations_sheet.dart';

Future<Future<GenerationsSheetResult?>> _openSheet(
  WidgetTester tester, {
  int? initial,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final completer = Completer<GenerationsSheetResult?>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final r = await showModalBottomSheet<GenerationsSheetResult>(
                context: context,
                isScrollControlled: true,
                builder: (_) => GenerationsSheet(initial: initial),
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
  return completer.future;
}

void main() {
  group('GenerationsSheet', () {
    testWidgets('renders the plural title and the Gen 1 card', (tester) async {
      await _openSheet(tester);

      expect(find.text('Generations'), findsOneWidget);
      expect(find.text('Generation I'), findsOneWidget);
    });

    testWidgets('tapping a generation pops with its id (tap = apply)', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      await tester.tap(find.text('Generation I'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, 1);
    });

    testWidgets('tapping the active generation again clears it', (
      tester,
    ) async {
      final future = await _openSheet(tester, initial: 1);

      await tester.tap(find.text('Generation I'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNull);
    });

    testWidgets(
      'Clear pops with a null value even when a generation is active',
      (tester) async {
        final future = await _openSheet(tester, initial: 1);

        expect(find.text('Clear'), findsOneWidget);
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        final result = await future;
        expect(result, isNotNull);
        expect(result!.value, isNull);
      },
    );

    testWidgets('Clear button is hidden when no generation is active', (
      tester,
    ) async {
      await _openSheet(tester);

      expect(find.text('Clear'), findsNothing);
    });

    testWidgets(
      'drag-to-dismiss pops `null` so caller leaves the generation untouched',
      (tester) async {
        final future = await _openSheet(tester, initial: 1);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        final result = await future;
        expect(result, isNull);
      },
    );

    testWidgets('golden', (tester) async {
      await _openSheet(tester, initial: 1);
      await expectLater(
        find.byType(GenerationsSheet),
        matchesGoldenFile('goldens/generations_sheet.png'),
      );
    });
  });
}
