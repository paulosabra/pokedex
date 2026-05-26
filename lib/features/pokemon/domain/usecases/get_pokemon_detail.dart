import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_pokemon_detail.g.dart';

/// Fetches a Pokémon's full detail by National Dex id (UC-06), cache-first.
///
/// A pure pass-through over [PokemonRepository.getPokemonDetail]; freshness
/// and stale-fallback policy lives in the repository.
class GetPokemonDetail {
  /// Creates a [GetPokemonDetail] bound to [_repository].
  const GetPokemonDetail(this._repository);

  final PokemonRepository _repository;

  /// Executes the use case for the given National Dex [id].
  Future<Result<PokemonDetail>> call(int id) =>
      _repository.getPokemonDetail(id);
}

/// Provides the [GetPokemonDetail] use case bound to the shared repository.
@riverpod
GetPokemonDetail getPokemonDetail(Ref ref) =>
    GetPokemonDetail(ref.watch(pokemonRepositoryProvider));
