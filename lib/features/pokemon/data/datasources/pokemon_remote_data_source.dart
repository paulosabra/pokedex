import 'package:dio/dio.dart';
import 'package:pokedex/core/network/error_mapper.dart';
import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_list_response_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/services/poke_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pokemon_remote_data_source.g.dart';

/// Fetches raw DTOs from the PokéAPI, translating transport errors into the
/// app's typed `Failure` vocabulary so the domain never sees a [DioException].
abstract interface class PokemonRemoteDataSource {
  /// Fetches one page of the Pokémon index (RN-14).
  Future<PokemonListResponseDto> fetchPage({
    required int limit,
    required int offset,
  });

  /// Fetches a single Pokémon's core data.
  Future<PokemonDto> fetchPokemon(int id);

  /// Fetches a Pokémon species' breeding/training/flavor data.
  Future<PokemonSpeciesDto> fetchSpecies(int id);

  /// Fetches a recursive evolution chain.
  Future<EvolutionChainDto> fetchEvolutionChain(int id);

  /// Fetches a type and its damage relations.
  Future<TypeDto> fetchType(int id);

  /// Fetches a Pokémon's location encounters.
  Future<List<LocationAreaEncounterDto>> fetchEncounters(int id);
}

/// Default [PokemonRemoteDataSource] backed by a Retrofit [PokeApiService].
class PokemonRemoteDataSourceImpl implements PokemonRemoteDataSource {
  /// Creates a [PokemonRemoteDataSourceImpl] wrapping [PokeApiService].
  const PokemonRemoteDataSourceImpl(this._service);

  final PokeApiService _service;

  @override
  Future<PokemonListResponseDto> fetchPage({
    required int limit,
    required int offset,
  }) => _guard(() => _service.getPokemonList(limit, offset));

  @override
  Future<PokemonDto> fetchPokemon(int id) =>
      _guard(() => _service.getPokemon(id));

  @override
  Future<PokemonSpeciesDto> fetchSpecies(int id) =>
      _guard(() => _service.getSpecies(id));

  @override
  Future<EvolutionChainDto> fetchEvolutionChain(int id) =>
      _guard(() => _service.getEvolutionChain(id));

  @override
  Future<TypeDto> fetchType(int id) => _guard(() => _service.getType(id));

  @override
  Future<List<LocationAreaEncounterDto>> fetchEncounters(int id) =>
      _guard(() => _service.getEncounters(id));

  /// Runs [request], converting any [DioException] or [FormatException] into a
  /// thrown `Failure` via [mapError].
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw mapError(e);
    } on FormatException catch (e) {
      throw mapError(e);
    }
  }
}

/// Provides the [PokemonRemoteDataSource], returning the abstract type so
/// callers depend on the interface (DIP).
@riverpod
PokemonRemoteDataSource pokemonRemoteDataSource(Ref ref) =>
    PokemonRemoteDataSourceImpl(ref.watch(pokeApiServiceProvider));
