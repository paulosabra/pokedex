import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_evolution_chain.g.dart';

/// Fetches a Pokémon's evolution tree by National Dex id (UC-07).
///
/// A pure pass-through over [PokemonRepository.getEvolutionChain].
class GetEvolutionChain {
  /// Creates a [GetEvolutionChain] bound to [_repository].
  const GetEvolutionChain(this._repository);

  final PokemonRepository _repository;

  /// Executes the use case for the given National Dex [id].
  Future<Result<EvolutionChain>> call(int id) =>
      _repository.getEvolutionChain(id);
}

/// Provides the [GetEvolutionChain] use case bound to the shared repository.
@riverpod
GetEvolutionChain getEvolutionChain(Ref ref) =>
    GetEvolutionChain(ref.watch(pokemonRepositoryProvider));
