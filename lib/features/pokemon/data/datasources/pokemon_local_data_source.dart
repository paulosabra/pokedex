import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

/// Reads and writes the local SQLite cache, returning raw Drift rows. The
/// repository (PR3) owns row→entity mapping, keeping this layer entity-free.
///
/// An abstraction over the concrete Drift `PokemonDao` so the repository can be
/// unit-tested against a fake (DIP).
abstract interface class PokemonLocalDataSource {
  /// Inserts or updates a batch of list summaries.
  Future<void> upsertSummaries(List<PokemonSummariesCompanion> summaries);

  /// Inserts or updates a single Pokémon detail.
  Future<void> upsertDetail(PokemonDetailsCompanion detail);

  /// Inserts or updates a single evolution chain.
  Future<void> upsertEvolutionChain(EvolutionChainsCompanion chain);

  /// Inserts or updates a single type's damage relations.
  Future<void> upsertTypeRelation(TypeRelationsCompanion relation);

  /// Reads a cached summary by National Dex id, or null on a cache miss.
  Future<PokemonSummaryRow?> readSummary(int id);

  /// Reads a cached detail by National Dex id, or null on a cache miss.
  Future<PokemonDetailRow?> readDetail(int id);

  /// Reads a cached evolution chain by id, or null on a cache miss.
  Future<EvolutionChainRow?> readEvolutionChain(int chainId);

  /// Reads a cached type's relations by id, or null on a cache miss.
  Future<TypeRelationRow?> readTypeRelation(int typeId);

  /// Queries cached summaries with an optional search term, [filter], and
  /// generation, ordered by [sort]. Search and filters combine cumulatively
  /// (RN-08); zero matches return an empty list, never an error.
  Future<List<PokemonSummaryRow>> querySummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
    int? generationId,
  });

  /// Like [querySummaries] but reactive: re-emits whenever the matching cached
  /// rows change.
  Stream<List<PokemonSummaryRow>> watchSummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
    int? generationId,
  });
}
