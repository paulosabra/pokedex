import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

/// The single cache-first entry point to Pokémon data (RN-02). Implementations
/// serve cache first and revalidate from the network in the background; all
/// fallible one-shot calls return a [Result].
abstract interface class PokemonRepository {
  /// Fetches one paginated page of the list (RN-14), cache-first.
  Future<Result<PokemonPage>> getPokemonList({
    required int limit,
    required int offset,
  });

  /// Fetches a Pokémon's full detail by National Dex id, cache-first.
  Future<Result<PokemonDetail>> getPokemonDetail(int id);

  /// Fetches a Pokémon's evolution tree by National Dex id, cache-first.
  Future<Result<EvolutionChain>> getEvolutionChain(int id);

  /// Searches cached summaries by name or number (RN-06/07), offline-capable.
  Future<Result<List<Pokemon>>> search(String query);

  /// Filters cached summaries (RN-08), ordered by [sort], offline-capable.
  Future<Result<List<Pokemon>>> filter(
    PokemonFilter filter, {
    required SortCriteria sort,
  });

  /// A reactive stream of cached summaries matching [filter], ordered by
  /// [sort]. A stream of cache state, so it yields a list, not a [Result].
  Stream<List<Pokemon>> watchCachedSummaries({
    required SortCriteria sort,
    PokemonFilter? filter,
  });
}
