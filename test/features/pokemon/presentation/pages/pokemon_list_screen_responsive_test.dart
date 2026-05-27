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

class _MockGetPokemonList extends Mock implements GetPokemonList {}

class _MockFindPokemon extends Mock implements FindPokemon {}

class _MockWatchPokemonList extends Mock implements WatchPokemonList {}

Pokemon _pokemon(int id) => Pokemon(
  id: id,
  name: 'pkmn-$id',
  imageUrl: '',
  generationId: 1,
  types: const [PokemonTypeId.grass],
);

Future<void> _pumpAt(WidgetTester tester, Size logical) async {
  // Pin DPR=1 so physical and logical px line up; otherwise the test default
  // DPR (3.0) collapses the viewport below the breakpoint we want to assert.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logical;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final getList = _MockGetPokemonList();
  final find = _MockFindPokemon();
  final watch = _MockWatchPokemonList();
  final cache = StreamController<List<Pokemon>>.broadcast();
  addTearDown(cache.close);

  final items = [for (var i = 1; i <= 6; i++) _pokemon(i)];
  when(
    () => getList.call(
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => Ok(PokemonPage(items: items, hasMore: false)));
  when(
    () => watch.call(
      sort: any(named: 'sort'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) => cache.stream);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        getPokemonListProvider.overrideWithValue(getList),
        findPokemonProvider.overrideWithValue(find),
        watchPokemonListProvider.overrideWithValue(watch),
      ],
      child: const MaterialApp(home: PokemonListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
    registerFallbackValue(const PokemonFilter());
  });

  group('PokemonListScreen responsive', () {
    testWidgets('compact (400 px) renders single-column ListView', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(400, 900));

      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(GridView), findsNothing);

      await expectLater(
        find.byType(PokemonListScreen),
        matchesGoldenFile('goldens/list_screen_compact.png'),
      );
    });

    testWidgets('medium (800 px) renders 2-column GridView', (tester) async {
      await _pumpAt(tester, const Size(800, 900));

      // Pin the contract: 2 columns at medium. Goldens alone don't catch a
      // regression behind a misguided --update-goldens rebaseline.
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);

      await expectLater(
        find.byType(PokemonListScreen),
        matchesGoldenFile('goldens/list_screen_medium.png'),
      );
    });

    testWidgets('expanded (1200 px) renders 3-column GridView', (tester) async {
      await _pumpAt(tester, const Size(1200, 900));

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);

      await expectLater(
        find.byType(PokemonListScreen),
        matchesGoldenFile('goldens/list_screen_expanded.png'),
      );
    });
  });
}
