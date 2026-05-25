import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/services/poke_api_service.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/queue_http_adapter.dart';

void main() {
  late QueueHttpAdapter adapter;

  PokeApiService serviceReturning(String body) {
    adapter = QueueHttpAdapter([(_) => jsonOk(body)]);
    final dio = Dio(BaseOptions(baseUrl: 'https://pokeapi.co/api/v2/'))
      ..httpClientAdapter = adapter;
    return PokeApiService(dio);
  }

  // Assert the FULL resolved URL (scheme + host + /api/v2 base + path) so a
  // dropped or wrong base URL fails loudly — a path suffix check would not.
  String url() => adapter.lastOptions!.uri.toString();

  group('PokeApiService', () {
    test('getPokemonList hits /pokemon with limit and offset', () async {
      final service = serviceReturning('{"count":1,"results":[]}');

      final result = await service.getPokemonList(20, 40);

      expect(result.count, 1);
      expect(
        url(),
        'https://pokeapi.co/api/v2/pokemon?limit=20&offset=40',
      );
    });

    test('getPokemon hits /pokemon/{id}', () async {
      final service = serviceReturning(fixture('pokemon_bulbasaur.json'));

      final result = await service.getPokemon(1);

      expect(result.name, 'bulbasaur');
      expect(url(), 'https://pokeapi.co/api/v2/pokemon/1');
    });

    test('getSpecies hits /pokemon-species/{id}', () async {
      final service = serviceReturning(fixture('species_bulbasaur.json'));

      final result = await service.getSpecies(1);

      expect(result.id, 1);
      expect(url(), 'https://pokeapi.co/api/v2/pokemon-species/1');
    });

    test('getEvolutionChain hits /evolution-chain/{id}', () async {
      final service = serviceReturning(fixture('evolution_chain_eevee.json'));

      final result = await service.getEvolutionChain(67);

      expect(result.id, 67);
      expect(url(), 'https://pokeapi.co/api/v2/evolution-chain/67');
    });

    test('getType hits /type/{id}', () async {
      final service = serviceReturning(fixture('type_grass.json'));

      final result = await service.getType(12);

      expect(result.name, 'grass');
      expect(url(), 'https://pokeapi.co/api/v2/type/12');
    });

    test(
      'getEncounters hits /pokemon/{id}/encounters and parses an array',
      () async {
        final service = serviceReturning(fixture('encounters_pikachu.json'));

        final result = await service.getEncounters(25);

        expect(result, isNotEmpty);
        expect(url(), 'https://pokeapi.co/api/v2/pokemon/25/encounters');
      },
    );
  });
}
