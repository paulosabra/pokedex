import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_remote_data_source.dart';
import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_list_response_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/services/poke_api_service.dart';

class _MockPokeApiService extends Mock implements PokeApiService {}

void main() {
  late _MockPokeApiService api;
  late PokemonRemoteDataSource dataSource;
  final requestOptions = RequestOptions(path: '/');

  DioException badResponse(int statusCode) => DioException(
    requestOptions: requestOptions,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
    ),
  );

  setUp(() {
    api = _MockPokeApiService();
    dataSource = PokemonRemoteDataSourceImpl(api);
  });

  group('PokemonRemoteDataSource success', () {
    test('fetchPage returns the list DTO', () async {
      const dto = PokemonListResponseDto(count: 1);
      when(() => api.getPokemonList(20, 0)).thenAnswer((_) async => dto);

      expect(await dataSource.fetchPage(limit: 20, offset: 0), dto);
      verify(() => api.getPokemonList(20, 0)).called(1);
    });

    test('fetchPokemon returns the Pokémon DTO', () async {
      const dto = PokemonDto(id: 1, name: 'bulbasaur', height: 7, weight: 69);
      when(() => api.getPokemon(1)).thenAnswer((_) async => dto);

      expect(await dataSource.fetchPokemon(1), dto);
    });

    test('fetchSpecies returns the species DTO', () async {
      const dto = PokemonSpeciesDto(
        id: 1,
        name: 'bulbasaur',
        genderRate: 1,
        captureRate: 45,
        baseHappiness: 50,
        hatchCounter: 20,
        growthRate: NamedApiResourceDto(url: ''),
        generation: NamedApiResourceDto(url: ''),
        evolutionChain: NamedApiResourceDto(url: ''),
      );
      when(() => api.getSpecies(1)).thenAnswer((_) async => dto);

      expect(await dataSource.fetchSpecies(1), dto);
    });

    test('fetchType returns the type DTO', () async {
      const dto = TypeDto(
        id: 12,
        name: 'grass',
        damageRelations: DamageRelationsDto(),
      );
      when(() => api.getType(12)).thenAnswer((_) async => dto);

      expect(await dataSource.fetchType(12), dto);
    });

    test('fetchEvolutionChain returns the chain DTO', () async {
      const dto = EvolutionChainDto(
        id: 67,
        chain: ChainLinkDto(species: NamedApiResourceDto(url: '')),
      );
      when(() => api.getEvolutionChain(67)).thenAnswer((_) async => dto);

      expect(await dataSource.fetchEvolutionChain(67), dto);
    });

    test('fetchEncounters returns the encounters list', () async {
      when(
        () => api.getEncounters(25),
      ).thenAnswer((_) async => const <LocationAreaEncounterDto>[]);

      expect(await dataSource.fetchEncounters(25), isEmpty);
    });
  });

  group('PokemonRemoteDataSource error mapping', () {
    test('fetchPokemon maps a 404 DioException to NotFoundFailure', () {
      when(() => api.getPokemon(any())).thenThrow(badResponse(404));

      expect(
        () => dataSource.fetchPokemon(1),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('fetchPokemon maps a FormatException to ParsingFailure', () {
      when(
        () => api.getPokemon(any()),
      ).thenThrow(const FormatException('bad'));

      expect(
        () => dataSource.fetchPokemon(1),
        throwsA(isA<ParsingFailure>()),
      );
    });

    test('fetchPage maps a connection timeout to TimeoutFailure', () {
      when(() => api.getPokemonList(any(), any())).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => dataSource.fetchPage(limit: 20, offset: 0),
        throwsA(isA<TimeoutFailure>()),
      );
    });

    test('fetchSpecies maps a 5xx DioException to ServerFailure', () {
      when(() => api.getSpecies(any())).thenThrow(badResponse(503));

      expect(
        () => dataSource.fetchSpecies(1),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('fetchType maps a connection error to NetworkFailure', () {
      when(() => api.getType(any())).thenThrow(
        DioException.connectionError(
          requestOptions: requestOptions,
          reason: 'down',
        ),
      );

      expect(
        () => dataSource.fetchType(1),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('fetchEvolutionChain maps a 404 to NotFoundFailure', () {
      when(() => api.getEvolutionChain(any())).thenThrow(badResponse(404));

      expect(
        () => dataSource.fetchEvolutionChain(67),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('fetchEncounters maps a receive timeout to TimeoutFailure', () {
      when(() => api.getEncounters(any())).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(
        () => dataSource.fetchEncounters(25),
        throwsA(isA<TimeoutFailure>()),
      );
    });
  });
}
