import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';
import 'package:pokedex/features/pokemon/presentation/view_models/pokemon_list_view_model.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/pokemon_card.dart'
    as adapter;

class _MockGetPokemonList extends Mock implements GetPokemonList {}

class _MockFindPokemon extends Mock implements FindPokemon {}

class _MockWatchPokemonList extends Mock implements WatchPokemonList {}

Pokemon _pokemon(int id, {String name = 'pkmn'}) => Pokemon(
  id: id,
  name: name,
  imageUrl: 'https://img/$id.png',
  generationId: 1,
  types: const [PokemonTypeId.grass],
);

List<Pokemon> _page(int start, int count) => [
  for (var i = 0; i < count; i++) _pokemon(start + i),
];

class _ListHarness {
  _ListHarness({
    required this.getList,
    required this.findPokemon,
    required this.watch,
    required this.cacheController,
  });

  final _MockGetPokemonList getList;
  final _MockFindPokemon findPokemon;
  final _MockWatchPokemonList watch;
  final StreamController<List<Pokemon>> cacheController;
}

_ListHarness _makeHarness({
  List<Pokemon>? firstPage,
  bool hasMore = true,
}) {
  final harness = _ListHarness(
    getList: _MockGetPokemonList(),
    findPokemon: _MockFindPokemon(),
    watch: _MockWatchPokemonList(),
    cacheController: StreamController<List<Pokemon>>.broadcast(),
  );
  when(
    () => harness.getList.call(
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer(
    (_) async =>
        Ok(PokemonPage(items: firstPage ?? _page(1, 24), hasMore: hasMore)),
  );
  when(
    () => harness.watch.call(
      sort: any(named: 'sort'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) => harness.cacheController.stream);
  when(
    () => harness.findPokemon.call(
      sort: any(named: 'sort'),
      query: any(named: 'query'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) async => Ok(_page(100, 3)));
  return harness;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _ListHarness harness,
  Size size = const Size(420, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(harness.cacheController.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        getPokemonListProvider.overrideWithValue(harness.getList),
        findPokemonProvider.overrideWithValue(harness.findPokemon),
        watchPokemonListProvider.overrideWithValue(harness.watch),
      ],
      child: const MaterialApp(home: PokemonListScreen()),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
    registerFallbackValue(const PokemonFilter());
  });

  group('PokemonListScreen', () {
    testWidgets('shows the skeleton while the first page is loading', (
      tester,
    ) async {
      final completer = Completer<Result<PokemonPage>>();
      final harness = _makeHarness();
      when(
        () => harness.getList.call(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      await _pumpScreen(tester, harness: harness);
      // First frame after pumpWidget — still loading.
      expect(find.byType(adapter.PokemonCard), findsNothing);
      expect(find.byType(GridView), findsOneWidget);

      completer.complete(const Ok(PokemonPage(hasMore: false)));
      await tester.pumpAndSettle();
    });

    testWidgets('renders cards from state after build completes', (
      tester,
    ) async {
      final harness = _makeHarness(firstPage: _page(1, 6), hasMore: false);
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      expect(find.byType(adapter.PokemonCard), findsNWidgets(6));
    });

    testWidgets('deep-link smoke: PokemonListScreen mounts at /', (
      tester,
    ) async {
      final harness = _makeHarness(firstPage: const [], hasMore: false);
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      expect(find.byType(PokemonListScreen), findsOneWidget);
    });

    testWidgets('empty state shows TE-04 message when query is set', (
      tester,
    ) async {
      final harness = _makeHarness(firstPage: _page(1, 3));
      when(
        () => harness.findPokemon.call(
          sort: any(named: 'sort'),
          query: any(named: 'query'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => const Ok(<Pokemon>[]));

      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzz');
      // Past the 300 ms debounce.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No Pokémon found for "zzzz".'), findsOneWidget);
    });

    testWidgets(
      'empty state shows TE-05 message when a filter is set but no query '
      '(resolved test-quality B1)',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 3));
        when(
          () => harness.findPokemon.call(
            sort: any(named: 'sort'),
            query: any(named: 'query'),
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) async => const Ok(<Pokemon>[]));

        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        // Apply a filter without entering a query so the empty branch hits
        // the filter-only message instead of the query message.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PokemonListScreen)),
        );
        container
            .read(pokemonListViewModelProvider.notifier)
            .applyFilter(const PokemonFilter(types: {PokemonTypeId.fire}));
        await tester.pumpAndSettle();

        expect(
          find.text('No Pokémon match the current filters.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'stream emission preserves scroll position (resolved blocker 3)',
      (tester) async {
        final harness = _makeHarness(firstPage: _page(1, 40));
        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        final scrollable = tester.widget<GridView>(find.byType(GridView));
        final controller = scrollable.controller;
        expect(controller, isNotNull);

        controller!.jumpTo(400);
        await tester.pumpAndSettle();
        final pixelsBefore = controller.position.pixels;

        // Emit a fresh cache snapshot with 1 extra item.
        harness.cacheController.add(_page(0, 41));
        await tester.pumpAndSettle();

        // Position should not have jumped.
        expect(controller.position.pixels, closeTo(pixelsBefore, 1));
      },
    );

    // The error state widget — and its test — land in PR4 alongside the
    // dedicated empty/error widgets under `lib/core/ui/states/`. Verifying
    // the PR2 placeholder here requires draining an uncaught zone error from
    // the failed build, which makes the test noisy and brittle.
  });
}
