import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/sheets/filters_sheet.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _FakeRepository implements PokemonRepository {
  _FakeRepository(this.indexState);

  IndexState indexState;

  @override
  Future<IndexState> readIndexState() async => indexState;

  // Unused-in-test methods throw — guards the test against silently
  // exercising code paths that aren't part of the sheet's surface.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected repository call ${invocation.memberName}',
  );
}

/// Opens the sheet and returns a future that resolves with whatever the sheet
/// pops with — including `null` when the user dismisses without interacting.
///
/// The default index state is `ready` so existing assertions that tap into
/// `Apply` / `Reset` / type chips don't have to wrestle with the shimmer
/// animation (which has no settled frame). Pass [indexState] explicitly to
/// exercise idle/stale/failed states.
Future<Future<FiltersSheetResult?>> _openSheet(
  WidgetTester tester, {
  PokemonFilter? initial,
  IndexState indexState = const IndexState(
    status: IndexStatus.ready,
    minId: 1,
    maxId: 1025,
    totalCount: 1025,
    generationIds: {1, 2, 3, 4, 5, 6, 7, 8, 9},
  ),
  bool waitForSettle = true,
}) async {
  // The sheet is taller than the default test surface (800×600); give it a
  // phone-sized canvas so every tappable target is on-screen.
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final connectivity = _MockConnectivity();
  when(
    connectivity.checkConnectivity,
  ).thenAnswer((_) async => [ConnectivityResult.wifi]);
  when(() => connectivity.onConnectivityChanged).thenAnswer(
    (_) => const Stream<List<ConnectivityResult>>.empty(),
  );

  final repo = _FakeRepository(indexState);

  final completer = Completer<FiltersSheetResult?>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(repo),
        connectivityProvider.overrideWithValue(connectivity),
      ],
      child: MaterialApp(
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
    ),
  );
  await tester.tap(find.text('open'));
  if (waitForSettle) {
    await tester.pumpAndSettle();
  } else {
    // Shimmer's infinite animation breaks `pumpAndSettle` — for idle-state
    // tests, draw two frames manually and assert against the static layout.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return completer.future;
}

void main() {
  group('FiltersSheet', () {
    testWidgets('renders title and the four section headings', (tester) async {
      await _openSheet(tester);

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Types'), findsOneWidget);
      expect(find.text('Weaknesses'), findsOneWidget);
      expect(find.text('Heights'), findsOneWidget);
      expect(find.text('Weights'), findsOneWidget);
    });

    testWidgets('selecting types and applying returns the filter', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      // Per-bucket keys disambiguate the visually-identical Types and
      // Weaknesses sections, where labels no longer appear alongside icons.
      await tester.tap(find.byKey(const Key('type-fire')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNotNull);
      expect(result.value!.types, {PokemonTypeId.fire});
      expect(result.value!.weaknesses, isEmpty);
      expect(result.value!.height, isNull);
      expect(result.value!.weight, isNull);
    });

    testWidgets('selecting weaknesses and applying returns the filter', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      // The sheet got taller after the Number Range section landed (commit
      // 4669121), so lower sections sit off-screen on the 1200px test
      // surface — scroll them in before tapping.
      await tester.ensureVisible(find.byKey(const Key('weakness-water')));
      await tester.tap(find.byKey(const Key('weakness-water')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply'));
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

      await tester.ensureVisible(find.byKey(const Key('height-short')));
      await tester.tap(find.byKey(const Key('height-short')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('height-short')));
      await tester.tap(find.byKey(const Key('height-short')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNotNull);
      expect(result!.value, isNull);
    });

    testWidgets('weight single-select toggles off when retapped', (
      tester,
    ) async {
      final future = await _openSheet(tester);

      await tester.ensureVisible(find.byKey(const Key('weight-light')));
      await tester.tap(find.byKey(const Key('weight-light')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('weight-light')));
      await tester.tap(find.byKey(const Key('weight-light')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply'));
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

    testWidgets(
      'Reset clears selections then Apply pops with a null value',
      (tester) async {
        final future = await _openSheet(
          tester,
          initial: const PokemonFilter(
            types: {PokemonTypeId.fire},
            height: HeightCategory.tall,
          ),
        );

        // Reset wipes the form state but leaves the sheet open (so the user
        // can adjust filters before applying). Apply on an empty form pops
        // the sheet with `value: null`.
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        final result = await future;
        expect(result, isNotNull);
        expect(result!.value, isNull);
      },
    );

    testWidgets(
      'dismissal without Apply pops `null` so caller leaves filter '
      'untouched (resolved VGV F1)',
      (tester) async {
        final future = await _openSheet(
          tester,
          initial: const PokemonFilter(types: {PokemonTypeId.fire}),
        );

        // Pops the modal route directly to assert the null-result contract
        // — `tester.tapAt(Offset(10, 10))` against the modal barrier hangs
        // in flutter_test when the sheet uses `isScrollControlled: true`,
        // so this test no longer exercises the barrier-tap path (only the
        // caller-visible null outcome is still pinned).
        Navigator.of(tester.element(find.byType(FiltersSheet))).pop();
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

    testWidgets(
      'subtitle reads X-of-Y while the backfill is hydrating',
      (tester) async {
        // `_openSheet` already defaults to a ready index of 1..1025.
        await _openSheet(tester);

        // The backfill coordinator's default progress is `hydrated: 0`, so
        // a fresh-index sheet renders "0 of 1025" until the drain has run.
        expect(find.text('Filtering across 0 of 1025 Pokémon'), findsOneWidget);
      },
    );

    testWidgets(
      'subtitle falls back to the marketing copy when the index is idle',
      (tester) async {
        await _openSheet(
          tester,
          indexState: const IndexState(status: IndexStatus.idle),
          waitForSettle: false,
        );

        expect(
          find.textContaining('Use advanced search to explore Pokémon'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'NumberRange shimmers + is disabled when the index is idle',
      (tester) async {
        await _openSheet(
          tester,
          indexState: const IndexState(status: IndexStatus.idle),
          waitForSettle: false,
        );

        // The disabled placeholder is wrapped in a Tooltip with the loading
        // copy; the live RangeSlider is absent.
        expect(find.byTooltip('Loading full catalogue…'), findsOneWidget);
        expect(find.byType(RangeSlider), findsNothing);
      },
    );

    testWidgets(
      'NumberRange goes live when the index reports ready',
      (tester) async {
        await _openSheet(tester);

        expect(find.byType(RangeSlider), findsOneWidget);
        expect(find.byTooltip('Loading full catalogue…'), findsNothing);
        // Slider rests at the live bounds.
        expect(find.text('1'), findsOneWidget);
        expect(find.text('1025'), findsOneWidget);
      },
    );

    testWidgets('preserves generationId from initial filter on apply', (
      tester,
    ) async {
      final future = await _openSheet(
        tester,
        initial: const PokemonFilter(generationId: 2),
      );

      await tester.tap(find.byKey(const Key('type-fire')));
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
