import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

/// Aggregate bounds of the local [PokemonIndex] table: the inclusive
/// `[minId, maxId]` range and `totalCount`. Returned as a record so callers
/// don't need a Freezed entity in the cache layer.
typedef PokemonIndexBounds = ({int minId, int maxId, int totalCount});

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

  /// Queries cached summaries with an optional search term and [filter],
  /// ordered by [sort]. Search and filters combine cumulatively (RN-08);
  /// zero matches return an empty list, never an error.
  Future<List<PokemonSummaryRow>> querySummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  });

  /// Like [querySummaries] but reactive: re-emits whenever the matching cached
  /// rows change.
  Stream<List<PokemonSummaryRow>> watchSummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  });

  /// Inserts or updates a batch of index rows in a single transaction.
  /// Web/IndexedDB jankiness is mitigated by chunking inside the DAO.
  Future<void> upsertIndex(List<PokemonIndexCompanion> rows);

  /// `min(id)` / `max(id)` / `count` over the index, or `null` when empty.
  Future<PokemonIndexBounds?> readIndexBounds();

  /// Distinct `generationId` values present in the index, ascending (drops
  /// the unknown generation 0). The Generations sheet renders one tile per id.
  Future<List<int>> listGenerationIds();

  /// All National-Dex ids belonging to [generationId], ordered ascending.
  /// Used by the Generations sheet to pick a random trio per tile.
  Future<List<int>> listGenerationMembers(int generationId);

  /// Drops an index row by id — used when a tap-into-detail returns 404,
  /// to keep the index from serving a ghost match.
  Future<void> evictIndexRow(int id);

  /// The shared `indexedAt` snapshot timestamp (every row in a single
  /// `/pokemon?limit=∞` upsert shares it), or `null` when empty.
  Future<int?> readIndexSnapshotAt();

  /// Queries the index with the same name/number conventions as
  /// [querySummaries] (numeric → equals on id, otherwise normalized-name
  /// substring). Returns rows ordered by [sort]; the repository upgrades
  /// each row to either a hydrated summary or a skeleton entity.
  Future<List<PokemonIndexRow>> queryIndex({
    required SortCriteria sort,
    String? query,
  });

  /// Reactive variant of [queryIndex] — re-emits on any index write so the
  /// UI sees skeleton→hydrated transitions live.
  Stream<List<PokemonIndexRow>> watchIndex({
    required SortCriteria sort,
    String? query,
  });

  /// Ids present in the index but missing from `pokemon_summaries`. Used by
  /// the backfill coordinator to drain "what's left to hydrate" — naturally
  /// resume-on-cold-start because the query is stateless.
  Future<List<int>> listMissingSummaryIds({int? limit});
}
