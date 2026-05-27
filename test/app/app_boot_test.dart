import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/app/app.dart';
import 'package:pokedex/app/router/app_router.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_detail_screen.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';

class _MockGetPokemonList extends Mock implements GetPokemonList {}

class _MockFindPokemon extends Mock implements FindPokemon {}

class _MockWatchPokemonList extends Mock implements WatchPokemonList {}

GoRouter _routerAt(String location) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PokemonListScreen(),
    ),
    GoRoute(
      path: '/pokemon/:id',
      builder: (context, state) => PokemonDetailScreen(
        id: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
);

/// Stubs the three Home use-case providers so [`PokemonListScreen`] can
/// build without instantiating the real Dio/SQLite/connectivity chain.
({
  _MockGetPokemonList getList,
  _MockFindPokemon findPokemon,
  _MockWatchPokemonList watch,
})
_setupListMocks() {
  final getList = _MockGetPokemonList();
  final findPokemon = _MockFindPokemon();
  final watch = _MockWatchPokemonList();
  when(
    () => getList.call(
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => const Ok(PokemonPage(hasMore: false)));
  when(
    () => watch.call(
      sort: any(named: 'sort'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) => const Stream<List<Pokemon>>.empty());
  return (getList: getList, findPokemon: findPokemon, watch: watch);
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortCriteria.numberAsc);
    registerFallbackValue(const PokemonFilter());
  });

  testWidgets('PokedexApp boots and composes a themed MaterialApp.router', (
    tester,
  ) async {
    final mocks = _setupListMocks();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith((ref) => _routerAt('/')),
          getPokemonListProvider.overrideWithValue(mocks.getList),
          findPokemonProvider.overrideWithValue(mocks.findPokemon),
          watchPokemonListProvider.overrideWithValue(mocks.watch),
        ],
        child: const PokedexApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routerConfig, isNotNull);
    expect(app.theme, isNotNull);
    expect(app.theme!.scaffoldBackgroundColor, AppColors.backgroundWhite);
    expect(find.byType(PokemonListScreen), findsOneWidget);
  });

  testWidgets('deep-linking to /pokemon/25 renders the detail placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith((ref) => _routerAt('/pokemon/25')),
        ],
        child: const PokedexApp(),
      ),
    );
    await tester.pumpAndSettle();

    final detail = tester.widget<PokemonDetailScreen>(
      find.byType(PokemonDetailScreen),
    );
    expect(detail.id, 25);
  });
}
