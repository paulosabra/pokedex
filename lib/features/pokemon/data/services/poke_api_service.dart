import 'package:dio/dio.dart';
import 'package:pokedex/core/network/dio_client.dart';
import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_list_response_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'poke_api_service.g.dart';

/// Retrofit client for the PokéAPI v2 endpoints consumed by the app.
///
/// The base URL is taken from the injected [Dio] (see `createPokeApiDio` and
/// `pokeApiBaseUrl`) — intentionally not duplicated in the `@RestApi`
/// annotation, which would otherwise shadow the Dio's configuration.
/// Return types are Freezed DTOs; Retrofit calls their `fromJson` automatically
/// via the default `JsonSerializable` parser.
@RestApi()
abstract class PokeApiService {
  /// Creates a [PokeApiService] backed by [dio].
  factory PokeApiService(Dio dio, {String? baseUrl}) = _PokeApiService;

  /// `GET /pokemon` — one page of the National Dex index (RN-14).
  @GET('/pokemon')
  Future<PokemonListResponseDto> getPokemonList(
    @Query('limit') int limit,
    @Query('offset') int offset,
  );

  /// `GET /pokemon?limit={limit}` — the full National-Dex index in one call.
  /// The brainstorm budgeted ~200 KB at `limit=100000` (PokéAPI returns
  /// `count` + `results[]` without forcing a per-id round-trip), powering
  /// Search / Sort / Filters / Generations across the entire catalogue.
  @GET('/pokemon')
  Future<PokemonListResponseDto> getPokemonIndex(@Query('limit') int limit);

  /// `GET /pokemon/{id}` — a single Pokémon's core data.
  @GET('/pokemon/{id}')
  Future<PokemonDto> getPokemon(@Path('id') int id);

  /// `GET /pokemon-species/{id}` — breeding, training, and flavor data.
  @GET('/pokemon-species/{id}')
  Future<PokemonSpeciesDto> getSpecies(@Path('id') int id);

  /// `GET /evolution-chain/{id}` — the recursive evolution tree.
  @GET('/evolution-chain/{id}')
  Future<EvolutionChainDto> getEvolutionChain(@Path('id') int id);

  /// `GET /type/{id}` — a type and its damage relations.
  @GET('/type/{id}')
  Future<TypeDto> getType(@Path('id') int id);

  /// `GET /pokemon/{id}/encounters` — a top-level array of location encounters.
  @GET('/pokemon/{id}/encounters')
  Future<List<LocationAreaEncounterDto>> getEncounters(@Path('id') int id);
}

/// The Retrofit-backed [PokeApiService] for the shared [Dio]. Stateless, so
/// the default codegen lifecycle is fine — recreating it is free.
@riverpod
PokeApiService pokeApiService(Ref ref) =>
    PokeApiService(ref.watch(dioProvider));
