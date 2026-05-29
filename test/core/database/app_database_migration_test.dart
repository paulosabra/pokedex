// Hide drift's isNull/isNotNull expression helpers so the matcher versions win
// (matches the convention used in pokemon_dao_test.dart).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/database/app_database.dart';

void main() {
  group('AppDatabase migration', () {
    test('schemaVersion is 3', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 3);
    });

    test(
      'a row inserted without an explicit weight gets the column default 0',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await db
            .into(db.pokemonSummaries)
            .insert(
              PokemonSummariesCompanion.insert(
                id: const Value(1),
                name: 'bulbasaur',
                nameNormalized: 'bulbasaur',
                primaryTypeId: 0,
                generationId: 1,
                height: 7,
                payloadJson: '{}',
                updatedAt: 0,
              ),
            );

        final row = await (db.select(
          db.pokemonSummaries,
        )..where((t) => t.id.equals(1))).getSingle();
        expect(row.weight, 0);
      },
    );

    test(
      'onUpgrade(1 -> 2) re-adds the weight column with default 0 to existing '
      'rows',
      () async {
        // Start at v3 (drift's onCreate runs createAll), then simulate v1 by
        // dropping the weight column AND the v3-only pokemon_index table.
        // Re-running the real onUpgrade callback exercises the same code path
        // drift will execute on a v1 user device.
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await db.customStatement(
          'ALTER TABLE pokemon_summaries DROP COLUMN weight',
        );
        await db.customStatement('DROP TABLE pokemon_index');
        await db.customStatement(
          'INSERT INTO pokemon_summaries '
          '(id, name, name_normalized, primary_type_id, generation_id, height, '
          'weakness_mask, payload_json, updated_at) '
          "VALUES (1, 'bulbasaur', 'bulbasaur', 0, 1, 7, 0, '{}', 0)",
        );

        await db.migration.onUpgrade(Migrator(db), 1, 3);

        final row = await (db.select(
          db.pokemonSummaries,
        )..where((t) => t.id.equals(1))).getSingle();
        expect(row.weight, 0);
      },
    );

    test(
      'onUpgrade(2 -> 3) creates pokemon_index without touching existing '
      'summaries',
      () async {
        // Start at v3, then simulate v2 by dropping the pokemon_index table.
        // A v2 user has populated PokemonSummaries; the v3 migration must
        // create the index table additively, leaving summaries intact.
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await db.customStatement('DROP TABLE pokemon_index');
        await db.customStatement(
          'INSERT INTO pokemon_summaries '
          '(id, name, name_normalized, primary_type_id, generation_id, height, '
          'weight, weakness_mask, payload_json, updated_at) '
          "VALUES (1, 'bulbasaur', 'bulbasaur', 0, 1, 7, 69, 0, '{}', 1000)",
        );

        await db.migration.onUpgrade(Migrator(db), 2, 3);

        // Summary survives untouched.
        final summary = await (db.select(
          db.pokemonSummaries,
        )..where((t) => t.id.equals(1))).getSingle();
        expect(summary.weight, 69);
        expect(summary.updatedAt, 1000);

        // Index table now exists and is empty.
        final indexRows = await db.select(db.pokemonIndex).get();
        expect(indexRows, isEmpty);
      },
    );
  });
}
