// Hide drift's isNull/isNotNull expression helpers so the matcher versions win.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_dao.dart';
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
    weaknessMask: Value(weaknessMask),
  );

  Future<List<int>> ids({
    SortCriteria sort = SortCriteria.numberAsc,
    String? query,
    PokemonFilter? filter,
    int? generationId,
  }) async {
    final rows = await dao.querySummaries(
      sort: sort,
      query: query,
      filter: filter,
      generationId: generationId,
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

    test('by generation', () async {
      expect(await ids(generationId: 2), [152]);
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

    test('combined filters intersect (RN-08)', () async {
      // grass type AND generation 1 → bulbasaur only (chikorita is gen 2).
      expect(
        await ids(
          filter: const PokemonFilter(types: {PokemonTypeId.grass}),
          generationId: 1,
        ),
        [1],
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

    test('a zero-result intersection returns empty, not an error', () async {
      expect(
        await ids(
          filter: const PokemonFilter(types: {PokemonTypeId.fire}),
          generationId: 2,
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
}
