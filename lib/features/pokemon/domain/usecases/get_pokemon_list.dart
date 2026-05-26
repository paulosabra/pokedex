import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_pokemon_list.g.dart';

/// Fetches one page of the paginated Pokémon list (UC-01, RF-03).
///
/// A pure pass-through over [PokemonRepository.getPokemonList]; pagination
/// policy (RN-14) lives in the repository.
class GetPokemonList {
  /// Creates a [GetPokemonList] bound to [_repository].
  const GetPokemonList(this._repository);

  final PokemonRepository _repository;

  /// Executes the use case for the given [limit] and [offset].
  Future<Result<PokemonPage>> call({
    required int limit,
    required int offset,
  }) => _repository.getPokemonList(limit: limit, offset: offset);
}

/// Provides the [GetPokemonList] use case bound to the shared repository.
@riverpod
GetPokemonList getPokemonList(Ref ref) =>
    GetPokemonList(ref.watch(pokemonRepositoryProvider));
