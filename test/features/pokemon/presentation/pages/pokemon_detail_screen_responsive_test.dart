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
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_detail_screen.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';

import '../fixtures/eevee_evolution_chain.dart';
import '../fixtures/pokemon_detail_builder.dart';

class _MockGetPokemonDetail extends Mock implements GetPokemonDetail {}

class _MockGetEvolutionChain extends Mock implements GetEvolutionChain {}

class _MockGetPokemonList extends Mock implements GetPokemonList {}

class _MockFindPokemon extends Mock implements FindPokemon {}

class _MockWatchPokemonList extends Mock implements WatchPokemonList {}

Pokemon _summary(int id) => Pokemon(
  id: id,
  name: 'pkmn-$id',
  imageUrl: '',
  generationId: 1,
  types: const [PokemonTypeId.grass],
);

Future<void> _pumpAt(WidgetTester tester, Size logical) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logical;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final getDetail = _MockGetPokemonDetail();
  final getChain = _MockGetEvolutionChain();
  final getList = _MockGetPokemonList();
  final findPokemon = _MockFindPokemon();
  final watch = _MockWatchPokemonList();
  final cache = StreamController<List<Pokemon>>.broadcast();
  addTearDown(cache.close);

  // Blank the sprite URL — golden tests can't reach the cached_network_image
  // file backing store because path_provider isn't mocked in unit tests.
  final detail = bulbasaurDetail().copyWith(
    summary: bulbasaurDetail().summary.copyWith(imageUrl: ''),
  );
  when(() => getDetail.call(any())).thenAnswer((_) async => Ok(detail));
  when(
    () => getChain.call(any()),
  ).thenAnswer((_) async => Ok(bulbasaurEvolutionChain()));

  // Master panel needs list providers to build on expanded breakpoint.
  final items = [for (var i = 1; i <= 6; i++) _summary(i)];
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
        getPokemonDetailProvider.overrideWithValue(getDetail),
        getEvolutionChainProvider.overrideWithValue(getChain),
        getPokemonListProvider.overrideWithValue(getList),
        findPokemonProvider.overrideWithValue(findPokemon),
        watchPokemonListProvider.overrideWithValue(watch),
      ],
      child: const MaterialApp(home: PokemonDetailScreen(id: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
    registerFallbackValue(const PokemonFilter());
  });

  group('PokemonDetailScreen responsive', () {
    testWidgets('compact viewport renders detail alone (no master panel)', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(400, 900));

      expect(find.byType(PokemonListScreen), findsNothing);
      await expectLater(
        find.byType(PokemonDetailScreen),
        matchesGoldenFile('goldens/detail_screen_compact.png'),
      );
    });

    testWidgets(
      'expanded viewport renders master + detail side-by-side (RF-46)',
      (tester) async {
        await _pumpAt(tester, const Size(1300, 900));

        // The list panel mounts as the master.
        expect(find.byType(PokemonListScreen), findsOneWidget);
        await expectLater(
          find.byType(PokemonDetailScreen),
          matchesGoldenFile('goldens/detail_screen_expanded.png'),
        );
      },
    );
  });
}
