import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/filters_sheet.dart';

/// Opens the sheet and returns a future that resolves with whatever the sheet
/// pops with — including `null` when the user dismisses without interacting.
Future<Future<FiltersSheetResult?>> _openSheet(
  WidgetTester tester, {
  PokemonFilter? initial,
}) async {
  // The sheet is taller than the default test surface (800×600); give it a
  // phone-sized canvas so every tappable target is on-screen.
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final completer = Completer<FiltersSheetResult?>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final r = await showModalBottomSheet<FiltersSheetResult>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FiltersSheet(initial: initial),
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
  group('FiltersSheet', () {
    testWidgets('renders title and the three section headings', (tester) async {
      await _openSheet(tester);

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Types'), findsOneWidget);
      expect(find.text('Weaknesses'), findsOneWidget);
      expect(find.text('Heights'), findsOneWidget);
    });

    testWidgets('selecting types and applying returns the filter', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      // "Fire" appears in both Types and Weaknesses sections; .first targets
      // the Types section above Weaknesses in the column.
      await tester.tap(find.text('Fire').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNotNull);
      expect(result.value!.types, {PokemonTypeId.fire});
      expect(result.value!.weaknesses, isEmpty);
      expect(result.value!.height, isNull);
    });

    testWidgets('selecting weaknesses and applying returns the filter', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      // The Weaknesses section is the second chip grid; .last targets it.
      await tester.tap(find.text('Water').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNotNull);
      expect(result.value!.weaknesses, {PokemonTypeId.water});
      expect(result.value!.types, isEmpty);
    });

    testWidgets('height single-select toggles off when retapped', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      await tester.tap(find.text('Short'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Short'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNull);
    });

    testWidgets('applying with no selection pops with a null value', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNull);
    });

    testWidgets('Clear pops with a null value even when selections exist', (
      tester,
    ) async {
      final future = await _openSheet(
        tester,
        initial: const PokemonFilter(
          types: {PokemonTypeId.fire},
          height: HeightCategory.tall,
        ),
      );

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNull);
    });

    testWidgets(
      'drag-to-dismiss pops `null` (no result) so caller leaves filter '
      'untouched (resolved VGV F1)',
      (tester) async {
        final future = await _openSheet(
          tester,
          initial: const PokemonFilter(types: {PokemonTypeId.fire}),
        );

        // Drag the sheet barrier down — taps outside the sheet content.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        final result = await future;
        expect(
          result,
          isNull,
          reason:
              'Caller relies on a null Future to skip applying a (value: null) '
              'clear — see PokemonListScreen._openFilters.',
        );
      },
    );

    testWidgets('title shows active filter count', (tester) async {
      await _openSheet(
        tester,
        initial: const PokemonFilter(
          types: {PokemonTypeId.fire, PokemonTypeId.water},
          height: HeightCategory.tall,
        ),
      );

      expect(find.text('Filters (3)'), findsOneWidget);
    });

    testWidgets('preserves generationId from initial filter on apply', (
      tester,
    ) async {
      final future = await _openSheet(
        tester,
        initial: const PokemonFilter(generationId: 2),
      );

      await tester.tap(find.text('Fire').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value?.generationId, 2);
      expect(result.value?.types, {PokemonTypeId.fire});
    });

    testWidgets('golden', (tester) async {
      await _openSheet(
        tester,
        initial: const PokemonFilter(
          types: {PokemonTypeId.fire},
          height: HeightCategory.tall,
        ),
      );

      await expectLater(
        find.byType(FiltersSheet),
        matchesGoldenFile('goldens/filters_sheet.png'),
      );
    });
  });
}
