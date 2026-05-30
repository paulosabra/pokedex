// Hide drift's isNull/isNotNull expression helpers so the matcher versions win.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_dao.dart';
import 'package:pokedex/features/pokemon/data/mappers/generation_ranges.dart';
import 'package:pokedex/features/pokemon/data/summary_encoding.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

void main() {
  late AppDatabase db;
  late PokemonDao dao;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dao = PokemonDao(db);
  });

  tearDown(() => db.close());

  PokemonSummariesCompanion summary({
    required int id,
    required String name,
    required PokemonTypeId primary,
    PokemonTypeId? secondary,
    int generationId = 1,
    int height = 7,
    int weight = 0,
    int weaknessMask = 0,
  }) => PokemonSummariesCompanion.insert(
    id: Value(id),
    name: name,
    nameNormalized: normalizeName(name),
    primaryTypeId: primary.index,
    generationId: generationId,
    height: height,
    payloadJson: '{}',
    updatedAt: 0,
    secondaryTypeId: Value(secondary?.index),
    weight: Value(weight),
    weaknessMask: Value(weaknessMask),
  );

  Future<List<int>> ids({
    SortCriteria sort = SortCriteria.numberAsc,
    String? query,
    PokemonFilter? filter,
  }) async {
    final rows = await dao.querySummaries(
      sort: sort,
      query: query,
      filter: filter,
    );
    return rows.map((r) => r.id).toList();
  }

  group('upsert + read', () {
    test('round-trips a summary', () async {
      await dao.upsertSummaries([
        summary(
          id: 1,
          name: 'bulbasaur',
          primary: PokemonTypeId.grass,
          secondary: PokemonTypeId.poison,
        ),
      ]);

      final row = await dao.readSummary(1);

      expect(row, isNotNull);
      expect(row!.name, 'bulbasaur');
      expect(row.primaryTypeId, PokemonTypeId.grass.index);
      expect(row.secondaryTypeId, PokemonTypeId.poison.index);
    });

    test(
      'upsert overwrites an existing row (insertOnConflictUpdate)',
      () async {
        await dao.upsertSummaries([
          summary(id: 1, name: 'bulbasaur', primary: PokemonTypeId.grass),
        ]);
        await dao.upsertSummaries([
          summary(id: 1, name: 'ivysaur', primary: PokemonTypeId.grass),
        ]);

        final row = await dao.readSummary(1);
        expect(row!.name, 'ivysaur');
      },
    );

    test('readSummary returns null on a cache miss', () async {
      expect(await dao.readSummary(999), isNull);
    });

    test('detail / evolution / type relations round-trip', () async {
      await dao.upsertDetail(
        PokemonDetailsCompanion.insert(
          id: const Value(1),
          payloadJson: '{"d":1}',
          updatedAt: 0,
        ),
      );
      await dao.upsertEvolutionChain(
        EvolutionChainsCompanion.insert(
          chainId: const Value(7),
          payloadJson: '{"c":7}',
          updatedAt: 0,
        ),
      );
      await dao.upsertTypeRelation(
        TypeRelationsCompanion.insert(
          typeId: const Value(12),
          payloadJson: '{"t":12}',
          updatedAt: 0,
        ),
      );

      expect((await dao.readDetail(1))!.payloadJson, '{"d":1}');
      expect((await dao.readEvolutionChain(7))!.payloadJson, '{"c":7}');
      expect((await dao.readTypeRelation(12))!.payloadJson, '{"t":12}');
      // Cache misses on every read return null.
      expect(await dao.readDetail(2), isNull);
      expect(await dao.readEvolutionChain(99), isNull);
      expect(await dao.readTypeRelation(99), isNull);
    });
  });

  group('search', () {
    setUp(() async {
      await dao.upsertSummaries([
        summary(id: 1, name: 'bulbasaur', primary: PokemonTypeId.grass),
        summary(id: 2, name: 'ivysaur', primary: PokemonTypeId.grass),
        summary(id: 4, name: 'charmander', primary: PokemonTypeId.fire),
        summary(id: 669, name: 'flabébé', primary: PokemonTypeId.fairy),
      ]);
    });

    test('by name is partial (substring)', () async {
      expect(await ids(query: 'saur'), [1, 2]);
    });

    test('by name is case-insensitive', () async {
      expect(await ids(query: 'CHARMANDER'), [4]);
    });

    test('by name is accent-insensitive (RN-07)', () async {
      expect(await ids(query: 'flabe'), [669]);
      expect(await ids(query: 'FLABÉBÉ'), [669]);
    });

    test('by number ignores leading zeros (RN-06)', () async {
      expect(await ids(query: '4'), [4]);
      expect(await ids(query: '04'), [4]);
      expect(await ids(query: '004'), [4]);
    });

    test('no name match returns an empty list, not an error', () async {
      expect(await ids(query: 'mewtwo'), isEmpty);
    });

    test('a number with no matching id returns empty', () async {
      expect(await ids(query: '99999'), isEmpty);
    });
  });

  group('filters', () {
    setUp(() async {
      await dao.upsertSummaries([
        summary(
          id: 1,
          name: 'bulbasaur',
          primary: PokemonTypeId.grass,
          secondary: PokemonTypeId.poison,
          weaknessMask: typeWeaknessMask({PokemonTypeId.fire}),
        ),
        summary(
          id: 4,
          name: 'charmander',
          primary: PokemonTypeId.fire,
          height: 6,
          weaknessMask: typeWeaknessMask({PokemonTypeId.water}),
        ),
        summary(
          id: 152,
          name: 'chikorita',
          primary: PokemonTypeId.grass,
          generationId: 2,
          height: 9,
        ),
        summary(
          id: 143,
          name: 'snorlax',
          primary: PokemonTypeId.normal,
          height: 21,
        ),
        summary(
          id: 31,
          name: 'nidoqueen',
          primary: PokemonTypeId.ground,
          height: 13,
        ),
      ]);
    });

    test('by primary or secondary type', () async {
      expect(
        await ids(filter: const PokemonFilter(types: {PokemonTypeId.fire})),
        [4],
      );
      // poison is bulbasaur's secondary type.
      expect(
        await ids(filter: const PokemonFilter(types: {PokemonTypeId.poison})),
        [1],
      );
      expect(
        await ids(filter: const PokemonFilter(types: {PokemonTypeId.grass})),
        [1, 152],
      );
    });

    test('a multi-type set unions matches (isIn OR-union)', () async {
      expect(
        await ids(
          filter: const PokemonFilter(
            types: {PokemonTypeId.fire, PokemonTypeId.grass},
          ),
        ),
        [1, 4, 152],
      );
    });

    test('by height bucket', () async {
      // short < 10 dm: bulbasaur(7), charmander(6), chikorita(9).
      expect(
        await ids(filter: const PokemonFilter(height: HeightCategory.short)),
        [1, 4, 152],
      );
      // medium 10–19 dm: nidoqueen(13).
      expect(
        await ids(filter: const PokemonFilter(height: HeightCategory.medium)),
        [31],
      );
      // tall >= 20 dm: snorlax(21).
      expect(
        await ids(filter: const PokemonFilter(height: HeightCategory.tall)),
        [143],
      );
    });

    test('by weakness bitmask (RF-15)', () async {
      expect(
        await ids(
          filter: const PokemonFilter(weaknesses: {PokemonTypeId.fire}),
        ),
        [1],
      );
      expect(
        await ids(
          filter: const PokemonFilter(weaknesses: {PokemonTypeId.water}),
        ),
        [4],
      );
      // A multi-type weakness set ORs its bits: matches mons weak to EITHER.
      expect(
        await ids(
          filter: const PokemonFilter(
            weaknesses: {PokemonTypeId.fire, PokemonTypeId.water},
          ),
        ),
        [1, 4],
      );
      // A mon with weaknessMask 0 (chikorita/snorlax) never matches.
      expect(
        await ids(
          filter: const PokemonFilter(weaknesses: {PokemonTypeId.grass}),
        ),
        isEmpty,
      );
    });

    test('a composed type + weakness + height filter intersects all', () async {
      // grass type AND weak-to-fire AND short height → bulbasaur only.
      expect(
        await ids(
          filter: const PokemonFilter(
            types: {PokemonTypeId.grass},
            weaknesses: {PokemonTypeId.fire},
            height: HeightCategory.short,
          ),
        ),
        [1],
      );
    });

    test('by generationId returns only Pokémon from that generation', () async {
      // The setUp inserts gen-1 rows by default; only chikorita is gen 2.
      expect(
        await ids(filter: const PokemonFilter(generationId: 1)),
        [1, 4, 31, 143],
      );
      // Chikorita is the only generationId 2 row.
      expect(await ids(filter: const PokemonFilter(generationId: 2)), [152]);
      // A generation with no rows yields an empty result, not an error.
      expect(await ids(filter: const PokemonFilter(generationId: 5)), isEmpty);
    });

    test('generationId intersects with types + height', () async {
      // grass type AND gen 1 AND short → bulbasaur only (chikorita is gen 2).
      expect(
        await ids(
          filter: const PokemonFilter(
            types: {PokemonTypeId.grass},
            height: HeightCategory.short,
            generationId: 1,
          ),
        ),
        [1],
      );
    });

    test('a zero-result intersection returns empty, not an error', () async {
      // fire type AND tall height → none (charmander is fire but short).
      expect(
        await ids(
          filter: const PokemonFilter(
            types: {PokemonTypeId.fire},
            height: HeightCategory.tall,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('height bucket boundaries', () {
    // id == height so the boundary values are easy to read in expectations.
    setUp(() async {
      await dao.upsertSummaries([
        for (final h in [9, 10, 19, 20])
          summary(id: h, name: 'h$h', primary: PokemonTypeId.normal, height: h),
      ]);
    });

    test('short is height < 10 (10 is excluded)', () async {
      expect(
        await ids(filter: const PokemonFilter(height: HeightCategory.short)),
        [9],
      );
    });

    test('medium is 10–19 inclusive', () async {
      expect(
        await ids(filter: const PokemonFilter(height: HeightCategory.medium)),
        [10, 19],
      );
    });

    test('tall is height >= 20 (20 is included)', () async {
      expect(
        await ids(filter: const PokemonFilter(height: HeightCategory.tall)),
        [20],
      );
    });
  });

  group('by weight bucket', () {
    setUp(() async {
      await dao.upsertSummaries([
        // pikachu @ 60 hg (light), pidgeot @ 395 hg (normal), snorlax @ 4600 hg
        // (heavy).
        summary(
          id: 25,
          name: 'pikachu',
          primary: PokemonTypeId.electric,
          weight: 60,
        ),
        summary(
          id: 18,
          name: 'pidgeot',
          primary: PokemonTypeId.normal,
          weight: 395,
        ),
        summary(
          id: 143,
          name: 'snorlax',
          primary: PokemonTypeId.normal,
          weight: 4600,
        ),
      ]);
    });

    test('WeightCategory.light returns only sub-100hg rows', () async {
      expect(
        await ids(filter: const PokemonFilter(weight: WeightCategory.light)),
        [25],
      );
    });

    test('WeightCategory.normal returns 100..499hg rows', () async {
      expect(
        await ids(filter: const PokemonFilter(weight: WeightCategory.normal)),
        [18],
      );
    });

    test('WeightCategory.heavy returns >=500hg rows', () async {
      expect(
        await ids(filter: const PokemonFilter(weight: WeightCategory.heavy)),
        [143],
      );
    });
  });

  group('weight bucket boundaries', () {
    // id == weight so the boundary values are easy to read in expectations.
    setUp(() async {
      await dao.upsertSummaries([
        for (final w in [99, 100, 499, 500])
          summary(id: w, name: 'w$w', primary: PokemonTypeId.normal, weight: w),
      ]);
    });

    test('light is weight < 100 (100 is excluded)', () async {
      expect(
        await ids(filter: const PokemonFilter(weight: WeightCategory.light)),
        [99],
      );
    });

    test('normal is 100..499 inclusive', () async {
      expect(
        await ids(filter: const PokemonFilter(weight: WeightCategory.normal)),
        [100, 499],
      );
    });

    test('heavy is weight >= 500 (500 is included)', () async {
      expect(
        await ids(filter: const PokemonFilter(weight: WeightCategory.heavy)),
        [500],
      );
    });
  });

  group('sort', () {
    setUp(() async {
      await dao.upsertSummaries([
        summary(id: 4, name: 'charmander', primary: PokemonTypeId.fire),
        summary(id: 1, name: 'bulbasaur', primary: PokemonTypeId.grass),
        summary(id: 2, name: 'ivysaur', primary: PokemonTypeId.grass),
      ]);
    });

    test('numberAsc (the default) / numberDesc', () async {
      expect(await ids(), [1, 2, 4]);
      expect(await ids(sort: SortCriteria.numberDesc), [4, 2, 1]);
    });

    test('nameAsc / nameDesc', () async {
      expect(await ids(sort: SortCriteria.nameAsc), [1, 4, 2]);
      expect(await ids(sort: SortCriteria.nameDesc), [2, 4, 1]);
    });
  });

  group('watchSummaries', () {
    test('emits the current cache, then re-emits on insert', () async {
      // Collect emissions via a listener and pump between steps so the initial
      // (empty) emit is observed before the insert — avoids a subscribe/insert
      // race that emitsInOrder would lose. Assert row identity, not just count.
      final emissions = <List<int>>[];
      final sub = dao
          .watchSummaries(sort: SortCriteria.numberAsc)
          .listen((rows) => emissions.add(rows.map((r) => r.id).toList()));

      await pumpEventQueue();
      await dao.upsertSummaries([
        summary(id: 1, name: 'bulbasaur', primary: PokemonTypeId.grass),
      ]);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions, [
        <int>[],
        [1],
      ]);
    });
  });

  PokemonIndexCompanion indexRow({
    required int id,
    required String name,
    int? generationId,
    int indexedAt = 0,
  }) => PokemonIndexCompanion.insert(
    id: Value(id),
    name: name,
    nameNormalized: normalizeName(name),
    generationId: generationId ?? generationForId(id),
    indexedAt: indexedAt,
  );

  group('PokemonIndex', () {
    test('upsertIndex / readIndexBounds round-trip', () async {
      await dao.upsertIndex([
        indexRow(id: 1, name: 'bulbasaur'),
        indexRow(id: 445, name: 'garchomp'),
        indexRow(id: 1025, name: 'pecharunt'),
      ]);

      final bounds = await dao.readIndexBounds();

      expect(bounds, isNotNull);
      expect(bounds!.minId, 1);
      expect(bounds.maxId, 1025);
      expect(bounds.totalCount, 3);
    });

    test('readIndexBounds returns null when empty', () async {
      expect(await dao.readIndexBounds(), isNull);
    });

    test(
      'upsertIndex chunks larger batches across multiple transactions',
      () async {
        // The DAO's internal batch size is 200; 450 rows exercises the chunking
        // loop without making the test slow.
        final rows = [
          for (var i = 1; i <= 450; i++) indexRow(id: i, name: 'p$i'),
        ];

        await dao.upsertIndex(rows);

        final bounds = await dao.readIndexBounds();
        expect(bounds!.totalCount, 450);
      },
    );

    test('upsertIndex overwrites existing rows on id conflict', () async {
      await dao.upsertIndex([indexRow(id: 1, name: 'bulbasaur')]);
      await dao.upsertIndex([indexRow(id: 1, name: 'venusaur')]);

      final rows = await dao.queryIndex(sort: SortCriteria.numberAsc);
      expect(rows, hasLength(1));
      expect(rows.first.name, 'venusaur');
    });

    test(
      'listGenerationIds returns distinct ids ascending, drops unknown',
      () async {
        await dao.upsertIndex([
          indexRow(id: 1, name: 'a', generationId: 1),
          indexRow(id: 152, name: 'b', generationId: 2),
          indexRow(id: 152, name: 'b', generationId: 2),
          indexRow(id: 906, name: 'c', generationId: 9),
          // generationId 0 (unknown) — should be filtered out.
          indexRow(id: 10001, name: 'mega', generationId: 0),
        ]);

        expect(await dao.listGenerationIds(), [1, 2, 9]);
      },
    );

    test('listGenerationMembers returns ids of the given generation', () async {
      await dao.upsertIndex([
        indexRow(id: 1, name: 'bulbasaur'),
        indexRow(id: 4, name: 'charmander'),
        indexRow(id: 7, name: 'squirtle'),
        indexRow(id: 152, name: 'chikorita'),
      ]);

      expect(await dao.listGenerationMembers(1), [1, 4, 7]);
      expect(await dao.listGenerationMembers(2), [152]);
      expect(await dao.listGenerationMembers(5), isEmpty);
    });

    test('evictIndexRow drops the row by id', () async {
      await dao.upsertIndex([
        indexRow(id: 1, name: 'a'),
        indexRow(id: 2, name: 'b'),
      ]);

      await dao.evictIndexRow(1);

      final rows = await dao.queryIndex(sort: SortCriteria.numberAsc);
      expect(rows.map((r) => r.id), [2]);
    });

    test('readIndexSnapshotAt returns the MAX(indexed_at) clock', () async {
      await dao.upsertIndex([
        indexRow(id: 1, name: 'a', indexedAt: 100),
        indexRow(id: 2, name: 'b', indexedAt: 100),
      ]);
      expect(await dao.readIndexSnapshotAt(), 100);

      // A second upsert with a newer snapshot bumps MAX even if some rows
      // still carry the older clock (recovery from a partial upsert).
      await dao.upsertIndex([indexRow(id: 3, name: 'c', indexedAt: 200)]);
      expect(await dao.readIndexSnapshotAt(), 200);
    });

    test('readIndexSnapshotAt returns null on an empty index', () async {
      expect(await dao.readIndexSnapshotAt(), isNull);
    });

    group('queryIndex search', () {
      setUp(() async {
        await dao.upsertIndex([
          indexRow(id: 1, name: 'bulbasaur'),
          indexRow(id: 2, name: 'ivysaur'),
          indexRow(id: 445, name: 'garchomp'),
          indexRow(id: 669, name: 'flabébé'),
        ]);
      });

      test('by name substring, case- and accent-insensitive (RN-07)', () async {
        final saur = await dao.queryIndex(
          sort: SortCriteria.numberAsc,
          query: 'SAUR',
        );
        expect(saur.map((r) => r.id), [1, 2]);

        final flabe = await dao.queryIndex(
          sort: SortCriteria.numberAsc,
          query: 'flabe',
        );
        expect(flabe.map((r) => r.id), [669]);
      });

      test('by numeric id with leading-zero tolerance (RN-06)', () async {
        for (final term in const ['445', '0445', '00445']) {
          final rows = await dao.queryIndex(
            sort: SortCriteria.numberAsc,
            query: term,
          );
          expect(rows.map((r) => r.id), [445]);
        }
      });

      test('empty query returns the full index in sort order', () async {
        expect(
          (await dao.queryIndex(
            sort: SortCriteria.numberDesc,
          )).map((r) => r.id),
          [669, 445, 2, 1],
        );
      });
    });

    group('listMissingSummaryIds', () {
      test('returns ids in the index but not in summaries', () async {
        await dao.upsertIndex([
          indexRow(id: 1, name: 'bulbasaur'),
          indexRow(id: 2, name: 'ivysaur'),
          indexRow(id: 3, name: 'venusaur'),
        ]);
        await dao.upsertSummaries([
          summary(id: 1, name: 'bulbasaur', primary: PokemonTypeId.grass),
        ]);

        expect(await dao.listMissingSummaryIds(), [2, 3]);
      });

      test('respects limit', () async {
        await dao.upsertIndex([
          for (var i = 1; i <= 10; i++) indexRow(id: i, name: 'p$i'),
        ]);
        expect(await dao.listMissingSummaryIds(limit: 3), [1, 2, 3]);
      });

      test('returns empty when every index row has a summary', () async {
        await dao.upsertIndex([indexRow(id: 1, name: 'a')]);
        await dao.upsertSummaries([
          summary(id: 1, name: 'a', primary: PokemonTypeId.grass),
        ]);
        expect(await dao.listMissingSummaryIds(), isEmpty);
      });
    });

    test('watchIndex re-emits when an index row is upserted', () async {
      final emissions = <List<int>>[];
      final sub = dao
          .watchIndex(sort: SortCriteria.numberAsc)
          .listen((rows) => emissions.add(rows.map((r) => r.id).toList()));

      await pumpEventQueue();
      await dao.upsertIndex([indexRow(id: 1, name: 'bulbasaur')]);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions, [
        <int>[],
        [1],
      ]);
    });
  });
}
