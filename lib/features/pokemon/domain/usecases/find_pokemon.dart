import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'find_pokemon.g.dart';

/// Reads cached summaries by intersecting a search query, a filter, and a
/// sort (UC-02…UC-05, RN-06/07/08). A null query or filter means "no
/// constraint on that axis".
///
/// A pure pass-through over [PokemonRepository.findPokemon].
class FindPokemon {
  /// Creates a [FindPokemon] bound to [_repository].
  const FindPokemon(this._repository);

  final PokemonRepository _repository;

  /// Executes the use case for the given [sort], optional [query], and
  /// optional [filter].
  Future<Result<List<Pokemon>>> call({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  }) => _repository.findPokemon(sort: sort, query: query, filter: filter);
}

/// Provides the [FindPokemon] use case bound to the shared repository.
@riverpod
FindPokemon findPokemon(Ref ref) =>
    FindPokemon(ref.watch(pokemonRepositoryProvider));
