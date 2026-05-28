import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_detail_screen.dart';

import '../fixtures/eevee_evolution_chain.dart';
import '../fixtures/pokemon_detail_builder.dart';

class _MockGetPokemonDetail extends Mock implements GetPokemonDetail {}

class _MockGetEvolutionChain extends Mock implements GetEvolutionChain {}

class _MockGetPokemonList extends Mock implements GetPokemonList {}

class _MockFindPokemon extends Mock implements FindPokemon {}

class _MockWatchPokemonList extends Mock implements WatchPokemonList {}

class _StubRepository extends Mock implements PokemonRepository {}

class _StubConnectivity extends Mock implements Connectivity {}

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

  // Stub catalogue-coverage providers so the master panel's list ViewModel
  // doesn't mount the real Drift database when the expanded breakpoint
  // brings up the master panel (which leaks a Timer at teardown).
  final repo = _StubRepository();
  final connectivity = _StubConnectivity();
  when(repo.readIndexState).thenAnswer(
    (_) async => const IndexState(
      status: IndexStatus.ready,
      minId: 1,
      maxId: 1025,
      totalCount: 1025,
      generationIds: {1, 2, 3, 4, 5, 6, 7, 8, 9},
    ),
  );
  when(
    () => repo.listGenerationMembers(any()),
  ).thenAnswer((_) async => <int>[]);
  when(
    connectivity.checkConnectivity,
  ).thenAnswer((_) async => [ConnectivityResult.none]);
  when(() => connectivity.onConnectivityChanged).thenAnswer(
    (_) => const Stream<List<ConnectivityResult>>.empty(),
  );

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
        pokemonRepositoryProvider.overrideWithValue(repo),
        connectivityProvider.overrideWithValue(connectivity),
      ],
      child: const MaterialApp(home: PokemonDetailScreen(id: 1)),
    ),
  );
  await tester.pumpAndSettle();
}
