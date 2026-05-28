import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

/// Cached list-card data for a Pokémon, with the columns needed for offline
/// search/filter/sort (RN-06/07/08).
@DataClassName('PokemonSummaryRow')
class PokemonSummaries extends Table {
  /// National Dex id (primary key; not auto-incremented).
  IntColumn get id => integer()();

  /// Display name (raw PokéAPI value, lowercase).
  TextColumn get name => text()();

  /// Lowercased, diacritics-stripped [name] for accent/case-insensitive search.
  TextColumn get nameNormalized => text()();

  /// Primary type, stored as `PokemonTypeId.index`.
  IntColumn get primaryTypeId => integer()();

  /// Secondary type as `PokemonTypeId.index`, or null for single-type Pokémon.
  IntColumn get secondaryTypeId => integer().nullable()();

  /// National Dex generation (RN-15).
  IntColumn get generationId => integer()();

  /// Raw PokéAPI height in decimetres.
  IntColumn get height => integer()();

  /// Raw PokéAPI weight in hectograms.
  IntColumn get weight => integer().withDefault(const Constant(0))();

  /// 18-bit weakness bitmask (bit i = `PokemonTypeId.values[i]`, RF-15).
  /// Populated by the repository in PR3; defaults to 0 until then.
  IntColumn get weaknessMask => integer().withDefault(const Constant(0))();

  /// Serialized domain entity; opaque to the cache layer.
  TextColumn get payloadJson => text()();

  /// Last-write epoch milliseconds, for TTL checks (RN-16).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Cached full-detail payload for a Pokémon.
@DataClassName('PokemonDetailRow')
class PokemonDetails extends Table {
  /// National Dex id (primary key).
  IntColumn get id => integer()();

  /// Serialized domain entity; opaque to the cache layer.
  TextColumn get payloadJson => text()();

  /// Last-write epoch milliseconds, for TTL checks (RN-16).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Cached evolution chain payload.
@DataClassName('EvolutionChainRow')
class EvolutionChains extends Table {
  /// Evolution-chain id (primary key).
  IntColumn get chainId => integer()();

  /// Serialized domain entity; opaque to the cache layer.
  TextColumn get payloadJson => text()();

  /// Last-write epoch milliseconds, for TTL checks (RN-16).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {chainId};
}

/// Cached type damage-relation payload (18 static rows, long TTL).
@DataClassName('TypeRelationRow')
class TypeRelations extends Table {
  /// Type id (primary key), as `PokemonTypeId.index`.
  IntColumn get typeId => integer()();

  /// Serialized damage relations; opaque to the cache layer.
  TextColumn get payloadJson => text()();

  /// Last-write epoch milliseconds, for TTL checks (RN-16).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {typeId};
}

/// Lightweight National-Dex index covering the entire catalogue, populated
/// from a single `GET /pokemon?limit=100000` call. Carries the bare minimum
/// to power Search / Sort / Filters / Generations across every Pokémon —
/// detail/summary hydration happens lazily into [PokemonSummaries] /
/// [PokemonDetails] (the index is a *superset* of those tables).
///
/// A separate table (not an `is_index_only` flag on [PokemonSummaries])
/// because the index has its own 30-day TTL (`kPokemonIndexTtl`) distinct
/// from the 7-day per-Pokémon TTL, and because filter SQL on
/// [PokemonSummaries] continues to operate on non-null type/weight columns
/// without a guard.
@DataClassName('PokemonIndexRow')
class PokemonIndex extends Table {
  /// National Dex id (primary key; not auto-incremented).
  IntColumn get id => integer()();

  /// Display name (raw PokéAPI value, lowercase).
  TextColumn get name => text()();

  /// Lowercased, diacritics-stripped [name] for accent/case-insensitive
  /// search (RN-07).
  TextColumn get nameNormalized => text()();

  /// National Dex generation 1–9, or `kUnknownGenerationId` (0) when the id
  /// falls outside the released ranges (e.g. alternate forms ≥ 10000).
  IntColumn get generationId => integer()();

  /// Snapshot epoch milliseconds — every row in a single `/pokemon` fetch
  /// shares the same value, so TTL is a column-level clock without needing
  /// `MAX(indexed_at)`.
  IntColumn get indexedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The on-device SQLite cache backing the cache-first repository (RN-02).
@DriftDatabase(
  tables: [
    PokemonSummaries,
    PokemonDetails,
    EvolutionChains,
    TypeRelations,
    PokemonIndex,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database — a native file on mobile/desktop, or a
  /// WASM/IndexedDB-backed database on the web (via `drift_flutter`).
  AppDatabase() : super(_openConnection());

  /// Creates a database over a caller-provided query executor, e.g. an
  /// in-memory connection for tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 — Figma's Filters dialog adds a weight category, so the cache needs
      // the raw hectogram value next to height.
      if (from < 2) {
        await m.addColumn(pokemonSummaries, pokemonSummaries.weight);
      }
      // v3 — full-database coverage adds the lightweight PokemonIndex table.
      // Additive: no row rewrites, no risk to existing summaries/details.
      if (from < 3) {
        await m.createTable(pokemonIndex);
      }
    },
  );
}

QueryExecutor _openConnection() => driftDatabase(
  name: 'pokedex',
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  ),
);

/// The application-scoped [AppDatabase]. `keepAlive: true` so the SQLite
/// handle survives provider rebuilds; disposing on rebuild would close the
/// database mid-flight.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
