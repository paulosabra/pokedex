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

/// Matches all digits, used to disambiguate number search from name search.
final _allDigits = RegExp(r'^\d+$');

/// Drift implementation of [PokemonLocalDataSource]. All search/filter/sort
/// runs as SQL over the cache for instant offline results (RN-08).
@DriftAccessor(
  tables: [PokemonSummaries, PokemonDetails, EvolutionChains, TypeRelations],
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
}

/// Provides the [PokemonLocalDataSource], returning the abstract type so the
/// repository provider depends on the interface (DIP).
@riverpod
PokemonLocalDataSource pokemonLocalDataSource(Ref ref) =>
    PokemonDao(ref.watch(appDatabaseProvider));
