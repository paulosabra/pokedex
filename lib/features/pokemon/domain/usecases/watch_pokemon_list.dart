import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watch_pokemon_list.g.dart';

/// Observes the cached Pokémon list as a reactive stream.
///
/// A pure pass-through over [PokemonRepository.watchCachedSummaries]. The
/// return type is intentionally `Stream<List<Pokemon>>` (not
/// `Stream<Result<...>>`): a stream of cache state isn't a fallible one-shot
/// operation, and the repository drops corrupt rows rather than poisoning the
/// stream.
class WatchPokemonList {
  /// Creates a [WatchPokemonList] bound to [_repository].
  const WatchPokemonList(this._repository);

  final PokemonRepository _repository;

  /// Executes the use case for the given [sort] and optional [filter].
  Stream<List<Pokemon>> call({
    required SortCriteria sort,
    PokemonFilter? filter,
  }) => _repository.watchCachedSummaries(sort: sort, filter: filter);
}

/// Provides the [WatchPokemonList] use case bound to the shared repository.
@riverpod
WatchPokemonList watchPokemonList(Ref ref) =>
    WatchPokemonList(ref.watch(pokemonRepositoryProvider));
