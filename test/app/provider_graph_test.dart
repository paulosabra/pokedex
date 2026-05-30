import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/router/app_router.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/core/network/dio_client.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/usecases/find_pokemon.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_list.dart';
import 'package:pokedex/features/pokemon/domain/usecases/watch_pokemon_list.dart';

class _FakeConnectivity extends Fake implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.wifi,
  ];
}

void main() {
  late ProviderContainer container;
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWithValue(_FakeConnectivity()),
        appDatabaseProvider.overrideWithValue(testDb),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await testDb.close();
  });

  group('keepAlive contract', () {
    test(
      'dio/appDb/connectivity survive a downstream consumer rebuild',
      () async {
        // Read each keepAlive provider once, capturing the instance identity.
        final dioBefore = container.read(dioProvider);
        final dbBefore = container.read(appDatabaseProvider);
        final connBefore = container.read(connectivityProvider);

        // Rebuild a downstream consumer of all three. Without keepAlive, the
        // upstream providers would dispose-and-recreate; with keepAlive, the
        // instances must survive.
        container
          ..invalidate(pokemonRepositoryProvider)
          ..read(pokemonRepositoryProvider);

        expect(identical(dioBefore, container.read(dioProvider)), isTrue);
        expect(
          identical(dbBefore, container.read(appDatabaseProvider)),
          isTrue,
        );
        expect(
          identical(connBefore, container.read(connectivityProvider)),
          isTrue,
        );
      },
    );

    test('routerProvider survives all-listeners-dropped', () async {
      // Open and close the only subscription. Under default (auto-dispose)
      // lifecycle the router would dispose; with keepAlive:true the instance
      // persists, so a subsequent read returns the same object.
      final subscription = container.listen(routerProvider, (_, _) {});
      final before = subscription.read();
      subscription.close();
      await Future<void>.delayed(Duration.zero);

      expect(identical(before, container.read(routerProvider)), isTrue);
    });
  });

  group('use case providers', () {
    test('each use case provider returns the expected runtime type', () {
      expect(container.read(getPokemonListProvider), isA<GetPokemonList>());
      expect(container.read(findPokemonProvider), isA<FindPokemon>());
      expect(container.read(getPokemonDetailProvider), isA<GetPokemonDetail>());
      expect(
        container.read(getEvolutionChainProvider),
        isA<GetEvolutionChain>(),
      );
      expect(container.read(watchPokemonListProvider), isA<WatchPokemonList>());
    });
  });
}
