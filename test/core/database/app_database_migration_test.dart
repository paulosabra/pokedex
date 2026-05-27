// Hide drift's isNull/isNotNull expression helpers so the matcher versions win
// (matches the convention used in pokemon_dao_test.dart).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/database/app_database.dart';

void main() {
  group('AppDatabase migration', () {
    test('schemaVersion is 2', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 2);
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
        // Start at v2 (drift's onCreate runs createAll), then simulate v1 by
        // dropping the weight column. Re-running the real onUpgrade callback
        // exercises the same code path drift will execute on a v1 user device.
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await db.customStatement(
          'ALTER TABLE pokemon_summaries DROP COLUMN weight',
        );
        await db.customStatement(
          'INSERT INTO pokemon_summaries '
          '(id, name, name_normalized, primary_type_id, generation_id, height, '
          'weakness_mask, payload_json, updated_at) '
          "VALUES (1, 'bulbasaur', 'bulbasaur', 0, 1, 7, 0, '{}', 0)",
        );

        await db.migration.onUpgrade(Migrator(db), 1, 2);

        final row = await (db.select(
          db.pokemonSummaries,
        )..where((t) => t.id.equals(1))).getSingle();
        expect(row.weight, 0);
      },
    );
  });
}
