import 'package:drift/drift.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_local_data_source.dart';
import 'package:pokedex/features/pokemon/data/summary_encoding.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pokemon_dao.g.dart';

/// Upper bound (exclusive) in decimetres for [HeightCategory.short] (< 1.0 m).
const _shortMaxDecimetres = 10;

/// Lower bound (inclusive) in decimetres for [HeightCategory.tall] (≥ 2.0 m).
const _tallMinDecimetres = 20;

/// Upper bound (exclusive) in hectograms for [WeightCategory.light] (< 10 kg).
const _lightMaxHectograms = 100;

/// Lower bound (inclusive) in hectograms for [WeightCategory.heavy] (≥ 50 kg).
const _heavyMinHectograms = 500;

/// Matches all digits, used to disambiguate number search from name search.
final _allDigits = RegExp(r'^\d+$');

/// Batch size for index bulk inserts. The 2026 brainstorm flags drift-web's
/// IndexedDB transactions as the bottleneck at large batch sizes; 200 keeps
/// each transaction commit comfortably under the worker's main-thread budget
/// on mobile Safari while staying coarse enough that ~1300 rows arrive in
/// ~7 transactions, not ~13. Drop to 50 if web measurements regress.
const _indexUpsertBatchSize = 200;

/// Drift implementation of [PokemonLocalDataSource]. All search/filter/sort
/// runs as SQL over the cache for instant offline results (RN-08).
@DriftAccessor(
  tables: [
    PokemonSummaries,
    PokemonDetails,
    EvolutionChains,
    TypeRelations,
    PokemonIndex,
  ],
)
class PokemonDao extends DatabaseAccessor<AppDatabase>
    with _$PokemonDaoMixin
    implements PokemonLocalDataSource {
  /// Creates a [PokemonDao] attached to the given [AppDatabase].
  PokemonDao(super.attachedDatabase);

  @override
  Future<void> upsertSummaries(List<PokemonSummariesCompanion> summaries) =>
      batch((b) => b.insertAllOnConflictUpdate(pokemonSummaries, summaries));

  @override
  Future<void> upsertDetail(PokemonDetailsCompanion detail) =>
      into(pokemonDetails).insertOnConflictUpdate(detail);

  @override
  Future<void> upsertEvolutionChain(EvolutionChainsCompanion chain) =>
      into(evolutionChains).insertOnConflictUpdate(chain);

  @override
  Future<void> upsertTypeRelation(TypeRelationsCompanion relation) =>
      into(typeRelations).insertOnConflictUpdate(relation);

  @override
  Future<PokemonSummaryRow?> readSummary(int id) => (select(
    pokemonSummaries,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<PokemonDetailRow?> readDetail(int id) =>
      (select(pokemonDetails)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<EvolutionChainRow?> readEvolutionChain(int chainId) => (select(
    evolutionChains,
  )..where((t) => t.chainId.equals(chainId))).getSingleOrNull();

  @override
  Future<TypeRelationRow?> readTypeRelation(int typeId) => (select(
    typeRelations,
  )..where((t) => t.typeId.equals(typeId))).getSingleOrNull();

  @override
  Future<List<PokemonSummaryRow>> querySummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  }) => _summaryQuery(sort: sort, query: query, filter: filter).get();

  @override
  Stream<List<PokemonSummaryRow>> watchSummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  }) => _summaryQuery(sort: sort, query: query, filter: filter).watch();

  SimpleSelectStatement<$PokemonSummariesTable, PokemonSummaryRow>
  _summaryQuery({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  }) {
    final statement = select(pokemonSummaries);

    final term = query?.trim() ?? '';
    if (term.isNotEmpty) {
      if (_allDigits.hasMatch(term)) {
        // Numeric search: parse strips leading zeros so 1/01/001 all hit #001.
        // tryParse guards an overflowing digit string; an unparseable id can't
        // match any row, so fall back to a never-true predicate (empty result).
        final id = int.tryParse(term);
        statement.where((t) => t.id.equals(id ?? -1));
      } else {
        final normalized = normalizeName(term);
        statement.where((t) => t.nameNormalized.like('%$normalized%'));
      }
    }

    if (filter != null) {
      if (filter.types.isNotEmpty) {
        final ids = filter.types.map((type) => type.index).toList();
        statement.where(
          (t) => t.primaryTypeId.isIn(ids) | t.secondaryTypeId.isIn(ids),
        );
      }
      if (filter.weaknesses.isNotEmpty) {
        final mask = typeWeaknessMask(filter.weaknesses);
        statement.where(
          (t) => t.weaknessMask.bitwiseAnd(Constant(mask)).isBiggerThanValue(0),
        );
      }
      final height = filter.height;
      if (height != null) {
        statement.where((t) => _heightPredicate(t, height));
      }
      final weight = filter.weight;
      if (weight != null) {
        statement.where((t) => _weightPredicate(t, weight));
      }
      final generationId = filter.generationId;
      if (generationId != null) {
        statement.where((t) => t.generationId.equals(generationId));
      }
      final range = filter.numberRange;
      if (range != null) {
        statement.where(
          (t) => t.id.isBetweenValues(range.min, range.max),
        );
      }
    }

    statement.orderBy([_ordering(sort)]);
    return statement;
  }

  Expression<bool> _heightPredicate(
    $PokemonSummariesTable t,
    HeightCategory category,
  ) {
    switch (category) {
      case HeightCategory.short:
        return t.height.isSmallerThanValue(_shortMaxDecimetres);
      case HeightCategory.medium:
        return t.height.isBiggerOrEqualValue(_shortMaxDecimetres) &
            t.height.isSmallerThanValue(_tallMinDecimetres);
      case HeightCategory.tall:
        return t.height.isBiggerOrEqualValue(_tallMinDecimetres);
    }
  }

  Expression<bool> _weightPredicate(
    $PokemonSummariesTable t,
    WeightCategory category,
  ) {
    switch (category) {
      case WeightCategory.light:
        return t.weight.isSmallerThanValue(_lightMaxHectograms);
      case WeightCategory.normal:
        return t.weight.isBiggerOrEqualValue(_lightMaxHectograms) &
            t.weight.isSmallerThanValue(_heavyMinHectograms);
      case WeightCategory.heavy:
        return t.weight.isBiggerOrEqualValue(_heavyMinHectograms);
    }
  }

  OrderingTerm Function($PokemonSummariesTable) _ordering(SortCriteria sort) {
    switch (sort) {
      case SortCriteria.numberAsc:
        return (t) => OrderingTerm.asc(t.id);
      case SortCriteria.numberDesc:
        return (t) => OrderingTerm.desc(t.id);
      case SortCriteria.nameAsc:
        return (t) => OrderingTerm.asc(t.name);
      case SortCriteria.nameDesc:
        return (t) => OrderingTerm.desc(t.name);
    }
  }

  // -- Index-aware queries (full-database coverage, schemaVersion 3) ---------

  @override
  Future<void> upsertIndex(List<PokemonIndexCompanion> rows) async {
    if (rows.isEmpty) return;
    // Drift opens its own transaction per `batch`, so we chunk explicitly and
    // call `batch` once per chunk to keep each transaction commit bounded.
    for (var start = 0; start < rows.length; start += _indexUpsertBatchSize) {
      final end = (start + _indexUpsertBatchSize).clamp(0, rows.length);
      final chunk = rows.sublist(start, end);
      await batch((b) => b.insertAllOnConflictUpdate(pokemonIndex, chunk));
    }
  }

  @override
  Future<PokemonIndexBounds?> readIndexBounds() async {
    final minExpr = pokemonIndex.id.min();
    final maxExpr = pokemonIndex.id.max();
    final countExpr = pokemonIndex.id.count();
    final row = await (selectOnly(
      pokemonIndex,
    )..addColumns([minExpr, maxExpr, countExpr])).getSingle();
    final min = row.read(minExpr);
    final max = row.read(maxExpr);
    final total = row.read(countExpr) ?? 0;
    if (min == null || max == null || total == 0) return null;
    return (minId: min, maxId: max, totalCount: total);
  }

  @override
  Future<List<int>> listGenerationIds() async {
    // DISTINCT generation_id, drop unknown generation 0, ascending.
    final generationCol = pokemonIndex.generationId;
    final query = selectOnly(pokemonIndex, distinct: true)
      ..addColumns([generationCol])
      ..where(generationCol.isBiggerThanValue(0))
      ..orderBy([OrderingTerm.asc(generationCol)]);
    final rows = await query.get();
    return rows.map((r) => r.read(generationCol)!).toList();
  }

  @override
  Future<List<int>> listGenerationMembers(int generationId) async {
    final rows =
        await (select(pokemonIndex)
              ..where((t) => t.generationId.equals(generationId))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    return rows.map((r) => r.id).toList();
  }

  @override
  Future<void> evictIndexRow(int id) =>
      (delete(pokemonIndex)..where((t) => t.id.equals(id))).go();

  @override
  Future<int?> readIndexSnapshotAt() async {
    // Every row in a single `/pokemon` upsert shares the same `indexedAt`,
    // so `MAX(indexed_at)` is the cheapest read of the snapshot clock and
    // tolerates legacy mixed-snapshot rows from a partial upsert recovery.
    final indexedAtExpr = pokemonIndex.indexedAt.max();
    final row = await (selectOnly(
      pokemonIndex,
    )..addColumns([indexedAtExpr])).getSingle();
    return row.read(indexedAtExpr);
  }

  @override
  Future<List<PokemonIndexRow>> queryIndex({
    required SortCriteria sort,
    String? query,
  }) => _indexQuery(sort: sort, query: query).get();

  @override
  Stream<List<PokemonIndexRow>> watchIndex({
    required SortCriteria sort,
    String? query,
  }) => _indexQuery(sort: sort, query: query).watch();

  @override
  Future<List<int>> listMissingSummaryIds({int? limit}) async {
    // Subquery rather than LEFT JOIN: SQLite optimizes NOT EXISTS to an
    // anti-join, and a JOIN would multiply rows when summaries are absent.
    final missing = pokemonIndex.id.isNotInQuery(
      selectOnly(pokemonSummaries)..addColumns([pokemonSummaries.id]),
    );
    var query = select(pokemonIndex)
      ..where((_) => missing)
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    if (limit != null) query = query..limit(limit);
    final rows = await query.get();
    return rows.map((r) => r.id).toList();
  }

  SimpleSelectStatement<$PokemonIndexTable, PokemonIndexRow> _indexQuery({
    required SortCriteria sort,
    String? query,
  }) {
    final statement = select(pokemonIndex);
    final term = query?.trim() ?? '';
    if (term.isNotEmpty) {
      if (_allDigits.hasMatch(term)) {
        final id = int.tryParse(term);
        statement.where((t) => t.id.equals(id ?? -1));
      } else {
        final normalized = normalizeName(term);
        statement.where((t) => t.nameNormalized.like('%$normalized%'));
      }
    }
    statement.orderBy([_indexOrdering(sort)]);
    return statement;
  }

  OrderingTerm Function($PokemonIndexTable) _indexOrdering(SortCriteria sort) {
    switch (sort) {
      case SortCriteria.numberAsc:
        return (t) => OrderingTerm.asc(t.id);
      case SortCriteria.numberDesc:
        return (t) => OrderingTerm.desc(t.id);
      case SortCriteria.nameAsc:
        return (t) => OrderingTerm.asc(t.name);
      case SortCriteria.nameDesc:
        return (t) => OrderingTerm.desc(t.name);
    }
  }
}

/// Provides the [PokemonLocalDataSource], returning the abstract type so the
/// repository provider depends on the interface (DIP).
@riverpod
PokemonLocalDataSource pokemonLocalDataSource(Ref ref) =>
    PokemonDao(ref.watch(appDatabaseProvider));
