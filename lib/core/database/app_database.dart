import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

/// The on-device SQLite cache backing the cache-first repository (RN-02).
@DriftDatabase(
  tables: [PokemonSummaries, PokemonDetails, EvolutionChains, TypeRelations],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database — a native file on mobile/desktop, or a
  /// WASM/IndexedDB-backed database on the web (via `drift_flutter`).
  AppDatabase() : super(_openConnection());

  /// Creates a database over a caller-provided query executor, e.g. an
  /// in-memory connection for tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

QueryExecutor _openConnection() => driftDatabase(
  name: 'pokedex',
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  ),
);
