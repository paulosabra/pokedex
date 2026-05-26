import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_dao.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_local_data_source.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_remote_data_source.dart';
import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_list_response_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/cache_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/evolution_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_detail_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/type_effectiveness.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';

import '../../../../helpers/fixtures.dart';

class _MockRemote extends Mock implements PokemonRemoteDataSource {}

class _MockConnectivity extends Mock implements Connectivity {}

/// Delegates to a real [PokemonLocalDataSource] but fails every detail write,
/// to exercise the repository's best-effort caching of a freshly composed
/// detail.
class _FailingDetailWriteLocal implements PokemonLocalDataSource {
  _FailingDetailWriteLocal(this._inner);

  final PokemonLocalDataSource _inner;

  @override
  Future<void> upsertDetail(PokemonDetailsCompanion detail) async {
    // A realistic cache-write failure is an Exception (e.g. Drift I/O), not an
    // Error; the repository's best-effort write only swallows Exceptions.
    throw Exception('cache write failed');
  }

  @override
  Future<void> upsertSummaries(List<PokemonSummariesCompanion> summaries) =>
      _inner.upsertSummaries(summaries);

  @override
  Future<void> upsertEvolutionChain(EvolutionChainsCompanion chain) =>
      _inner.upsertEvolutionChain(chain);

  @override
  Future<void> upsertTypeRelation(TypeRelationsCompanion relation) =>
      _inner.upsertTypeRelation(relation);

  @override
  Future<PokemonSummaryRow?> readSummary(int id) => _inner.readSummary(id);

  @override
  Future<PokemonDetailRow?> readDetail(int id) => _inner.readDetail(id);

  @override
  Future<EvolutionChainRow?> readEvolutionChain(int chainId) =>
      _inner.readEvolutionChain(chainId);

  @override
  Future<TypeRelationRow?> readTypeRelation(int typeId) =>
      _inner.readTypeRelation(typeId);

  @override
  Future<List<PokemonSummaryRow>> querySummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  }) => _inner.querySummaries(sort: sort, query: query, filter: filter);

  @override
  Stream<List<PokemonSummaryRow>> watchSummaries({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  }) => _inner.watchSummaries(sort: sort, query: query, filter: filter);
}

void main() {
  late AppDatabase db;
  late PokemonDao dao;
  late _MockRemote remote;
  late _MockConnectivity connectivity;
  late PokemonRepositoryImpl repo;
  late DateTime clock;

  final pokemonDto = PokemonDto.fromJson(fixtureJson('pokemon_bulbasaur.json'));
  final speciesDto = PokemonSpeciesDto.fromJson(
    fixtureJson('species_bulbasaur.json'),
  );
  final typeDto = TypeDto.fromJson(fixtureJson('type_grass.json'));
  final evolutionDto = EvolutionChainDto.fromJson(
    fixtureJson('evolution_chain_bulbasaur.json'),
  );
  final encounters = [
    for (final e in fixtureJsonArray('encounters_bulbasaur.json'))
      LocationAreaEncounterDto.fromJson(e as Map<String, dynamic>),
  ];

  int nowMs() => clock.millisecondsSinceEpoch;
  int daysAgo(int days) =>
      clock.subtract(Duration(days: days)).millisecondsSinceEpoch;

  void goOnline() => when(
    () => connectivity.checkConnectivity(),
  ).thenAnswer((_) async => [ConnectivityResult.wifi]);

  void goOffline() => when(
    () => connectivity.checkConnectivity(),
  ).thenAnswer((_) async => [ConnectivityResult.none]);

  void stubComposeSuccess() {
    when(() => remote.fetchPokemon(1)).thenAnswer((_) async => pokemonDto);
    when(() => remote.fetchSpecies(1)).thenAnswer((_) async => speciesDto);
    when(() => remote.fetchType(any())).thenAnswer((_) async => typeDto);
    when(() => remote.fetchEncounters(1)).thenAnswer((_) async => encounters);
  }

  Future<void> seedDetail(PokemonDetail detail, {required int updatedAt}) =>
      dao.upsertDetail(detailToCompanion(detail, nowMs: updatedAt));

  PokemonDetail composedDetail() => pokemonDetailFromDtos(
    pokemon: pokemonDto,
    species: speciesDto,
    effectiveness: computeTypeEffectiveness(const [], const {}),
    encounters: const [],
  );

  setUp(() {
    clock = DateTime.utc(2026);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = PokemonDao(db);
    remote = _MockRemote();
    connectivity = _MockConnectivity();
    repo = PokemonRepositoryImpl(remote, dao, connectivity, () => clock);
    goOnline();
  });

  tearDown(() => db.close());

  group('getPokemonList', () {
    test('offline returns NetworkFailure', () async {
      goOffline();
      final result = await repo.getPokemonList(limit: 20, offset: 0);
      expect((result as Err<PokemonPage>).failure, isA<NetworkFailure>());
    });

    test(
      'fetches the page, builds + caches summaries (hasMore true)',
      () async {
        when(() => remote.fetchType(any())).thenAnswer((_) async => typeDto);
        when(
          () => remote.fetchPage(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => const PokemonListResponseDto(
            count: 2,
            next: 'https://pokeapi.co/api/v2/pokemon?offset=20&limit=20',
            results: [
              NamedApiResourceDto(url: 'https://pokeapi.co/api/v2/pokemon/1/'),
            ],
          ),
        );
        when(() => remote.fetchPokemon(1)).thenAnswer((_) async => pokemonDto);

        final result = await repo.getPokemonList(limit: 20, offset: 0);

        final page = (result as Ok<PokemonPage>).value;
        expect(page.items, hasLength(1));
        expect(page.hasMore, isTrue);
        expect(await dao.readSummary(1), isNotNull);
      },
    );

    test('an offset past the end yields an empty page (no error)', () async {
      when(() => remote.fetchType(any())).thenAnswer((_) async => typeDto);
      when(
        () => remote.fetchPage(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const PokemonListResponseDto(count: 0));

      final result = await repo.getPokemonList(limit: 20, offset: 99999);

      final page = (result as Ok<PokemonPage>).value;
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('a failing per-id fetch fails the whole page', () async {
      when(() => remote.fetchType(any())).thenAnswer((_) async => typeDto);
      when(
        () => remote.fetchPage(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => const PokemonListResponseDto(
          count: 1,
          results: [
            NamedApiResourceDto(url: 'https://pokeapi.co/api/v2/pokemon/1/'),
          ],
        ),
      );
      when(() => remote.fetchPokemon(1)).thenThrow(const ServerFailure());

      final result = await repo.getPokemonList(limit: 20, offset: 0);

      expect((result as Err<PokemonPage>).failure, isA<ServerFailure>());
    });
  });

  group('getPokemonDetail', () {
    test('cold miss online composes, returns and caches', () async {
      stubComposeSuccess();

      final result = await repo.getPokemonDetail(1);

      expect(result, isA<Ok<PokemonDetail>>());
      expect(await dao.readDetail(1), isNotNull);
    });

    test('cold miss offline returns NetworkFailure', () async {
      goOffline();
      final result = await repo.getPokemonDetail(1);
      expect((result as Err<PokemonDetail>).failure, isA<NetworkFailure>());
    });

    test('a failing mandatory /pokemon returns the failure', () async {
      when(() => remote.fetchPokemon(1)).thenThrow(const NotFoundFailure());
      final result = await repo.getPokemonDetail(1);
      expect((result as Err<PokemonDetail>).failure, isA<NotFoundFailure>());
    });

    test(
      'fresh cache hit returns cache and revalidates in background',
      () async {
        stubComposeSuccess();
        final cached = composedDetail().copyWith(description: 'CACHED-FRESH');
        await seedDetail(cached, updatedAt: nowMs());

        final result = await repo.getPokemonDetail(1);
        // The cached value is returned immediately, not the network value.
        expect((result as Ok<PokemonDetail>).value.description, 'CACHED-FRESH');

        await pumpEventQueue();
        verify(() => remote.fetchPokemon(1)).called(1);
      },
    );

    test('stale cache + network success returns the fresh value', () async {
      stubComposeSuccess();
      final stale = composedDetail().copyWith(description: 'STALE');
      await seedDetail(stale, updatedAt: daysAgo(8));

      final result = await repo.getPokemonDetail(1);

      expect((result as Ok<PokemonDetail>).value.description, isNot('STALE'));
    });

    test(
      'stale cache + network failure serves the stale value (TE-02)',
      () async {
        when(() => remote.fetchPokemon(1)).thenThrow(const NetworkFailure());
        final stale = composedDetail().copyWith(description: 'STALE');
        await seedDetail(stale, updatedAt: daysAgo(8));

        final result = await repo.getPokemonDetail(1);

        expect((result as Ok<PokemonDetail>).value.description, 'STALE');
      },
    );

    test(
      'stale cache offline serves the stale value without a network call',
      () async {
        goOffline();
        when(
          () => remote.fetchPokemon(any()),
        ).thenThrow(const NetworkFailure());
        final stale = composedDetail().copyWith(description: 'STALE');
        await seedDetail(stale, updatedAt: daysAgo(8));

        final result = await repo.getPokemonDetail(1);

        expect((result as Ok<PokemonDetail>).value.description, 'STALE');
        verifyNever(() => remote.fetchPokemon(any()));
      },
    );

    test('a failed cache write still returns the composed detail', () async {
      stubComposeSuccess();
      final repoWithFailingWrites = PokemonRepositoryImpl(
        remote,
        _FailingDetailWriteLocal(dao),
        connectivity,
        () => clock,
      );

      final result = await repoWithFailingWrites.getPokemonDetail(1);

      expect(
        (result as Ok<PokemonDetail>).value.description,
        composedDetail().description,
      );
    });

    test('corrupt cache online is treated as a miss and recomposed', () async {
      stubComposeSuccess();
      await dao.upsertDetail(
        PokemonDetailsCompanion.insert(
          id: const Value(1),
          payloadJson: '{"corrupt":true}',
          updatedAt: nowMs(),
        ),
      );

      final result = await repo.getPokemonDetail(1);

      expect(result, isA<Ok<PokemonDetail>>());
      verify(() => remote.fetchPokemon(1)).called(1);
    });

    test('corrupt cache offline returns CacheFailure', () async {
      goOffline();
      await dao.upsertDetail(
        PokemonDetailsCompanion.insert(
          id: const Value(1),
          payloadJson: '{"corrupt":true}',
          updatedAt: nowMs(),
        ),
      );

      final result = await repo.getPokemonDetail(1);

      expect((result as Err<PokemonDetail>).failure, isA<CacheFailure>());
    });

    test(
      'a partial compose (species fails) is returned but not cached',
      () async {
        when(() => remote.fetchPokemon(1)).thenAnswer((_) async => pokemonDto);
        when(() => remote.fetchSpecies(1)).thenThrow(const ServerFailure());
        when(() => remote.fetchType(any())).thenAnswer((_) async => typeDto);
        when(
          () => remote.fetchEncounters(1),
        ).thenAnswer((_) async => encounters);

        final result = await repo.getPokemonDetail(1);

        final detail = (result as Ok<PokemonDetail>).value;
        expect(detail.description, isEmpty);
        expect(await dao.readDetail(1), isNull);
      },
    );

    test('degrades when type and encounters fetches fail', () async {
      when(() => remote.fetchPokemon(1)).thenAnswer((_) async => pokemonDto);
      when(() => remote.fetchSpecies(1)).thenAnswer((_) async => speciesDto);
      when(() => remote.fetchType(any())).thenThrow(const ServerFailure());
      when(() => remote.fetchEncounters(1)).thenThrow(const ServerFailure());

      final result = await repo.getPokemonDetail(1);

      final detail = (result as Ok<PokemonDetail>).value;
      expect(detail.weaknesses, isEmpty);
      expect(detail.locations, isEmpty);
      expect(await dao.readDetail(1), isNull);
    });

    test('reuses fresh cached type relations instead of refetching', () async {
      // Pre-warm bulbasaur's types so the compose hits the type cache.
      for (final type in [PokemonTypeId.grass, PokemonTypeId.poison]) {
        await dao.upsertTypeRelation(
          typeRelationToCompanion(
            type,
            typeDto.damageRelations,
            nowMs: nowMs(),
          ),
        );
      }
      when(() => remote.fetchPokemon(1)).thenAnswer((_) async => pokemonDto);
      when(() => remote.fetchSpecies(1)).thenAnswer((_) async => speciesDto);
      when(() => remote.fetchEncounters(1)).thenAnswer((_) async => encounters);

      final result = await repo.getPokemonDetail(1);

      expect(result, isA<Ok<PokemonDetail>>());
      verifyNever(() => remote.fetchType(any()));
    });
  });

  group('getEvolutionChain', () {
    test('online resolves chain id via species and caches', () async {
      when(() => remote.fetchSpecies(1)).thenAnswer((_) async => speciesDto);
      when(
        () => remote.fetchEvolutionChain(any()),
      ).thenAnswer((_) async => evolutionDto);

      final result = await repo.getEvolutionChain(1);

      expect(result, isA<Ok<dynamic>>());
      final chainId = speciesDto.evolutionChain.idFromUrl!;
      expect(await dao.readEvolutionChain(chainId), isNotNull);
    });

    test('offline returns NetworkFailure', () async {
      goOffline();
      final result = await repo.getEvolutionChain(1);
      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('serves a fresh cached chain without refetching it', () async {
      when(() => remote.fetchSpecies(1)).thenAnswer((_) async => speciesDto);
      final chainId = speciesDto.evolutionChain.idFromUrl!;
      await dao.upsertEvolutionChain(
        evolutionToCompanion(
          chainId,
          evolutionChainFromDto(evolutionDto),
          nowMs: nowMs(),
        ),
      );

      final result = await repo.getEvolutionChain(1);

      expect(result, isA<Ok<dynamic>>());
      verifyNever(() => remote.fetchEvolutionChain(any()));
    });

    test('a species failure surfaces as an error', () async {
      when(() => remote.fetchSpecies(1)).thenThrow(const ServerFailure());
      final result = await repo.getEvolutionChain(1);
      expect((result as Err).failure, isA<ServerFailure>());
    });

    test('a stale cached chain is refetched and updated', () async {
      when(() => remote.fetchSpecies(1)).thenAnswer((_) async => speciesDto);
      when(
        () => remote.fetchEvolutionChain(any()),
      ).thenAnswer((_) async => evolutionDto);
      final chainId = speciesDto.evolutionChain.idFromUrl!;
      await dao.upsertEvolutionChain(
        evolutionToCompanion(
          chainId,
          evolutionChainFromDto(evolutionDto),
          nowMs: daysAgo(8),
        ),
      );

      final result = await repo.getEvolutionChain(1);

      expect(result, isA<Ok<dynamic>>());
      verify(() => remote.fetchEvolutionChain(chainId)).called(1);
    });

    test('a species without a chain id returns NotFoundFailure', () async {
      when(() => remote.fetchSpecies(1)).thenAnswer(
        (_) async => speciesDto.copyWith(
          evolutionChain: const NamedApiResourceDto(url: ''),
        ),
      );

      final result = await repo.getEvolutionChain(1);

      expect((result as Err).failure, isA<NotFoundFailure>());
    });
  });

  group('findPokemon / watch (cache-backed)', () {
    setUp(() async {
      final bulbasaur = composedDetail().summary;
      final charmander = bulbasaur.copyWith(
        id: 4,
        name: 'charmander',
        types: const [PokemonTypeId.fire],
      );
      await dao.upsertSummaries([
        summaryToCompanion(
          bulbasaur,
          heightDecimetres: 7,
          weaknessMask: 0,
          nowMs: nowMs(),
        ),
        summaryToCompanion(
          charmander,
          heightDecimetres: 7,
          weaknessMask: 0,
          nowMs: nowMs(),
        ),
      ]);
    });

    test('with only sort returns every row in sort order', () async {
      final result = await repo.findPokemon(sort: SortCriteria.numberDesc);
      final list = (result as Ok<List<Pokemon>>).value;
      expect(list.map((p) => p.id), [4, 1]);
    });

    test('with only query narrows by name', () async {
      final result = await repo.findPokemon(
        sort: SortCriteria.numberAsc,
        query: 'bulba',
      );
      final list = (result as Ok<List<Pokemon>>).value;
      expect(list.map((p) => p.id), [1]);
    });

    test('with only filter narrows by type', () async {
      final result = await repo.findPokemon(
        sort: SortCriteria.numberAsc,
        filter: const PokemonFilter(types: {PokemonTypeId.fire}),
      );
      final list = (result as Ok<List<Pokemon>>).value;
      expect(list.map((p) => p.id), [4]);
    });

    test('with query + filter intersects both (RN-08)', () async {
      final result = await repo.findPokemon(
        sort: SortCriteria.numberAsc,
        query: 'char',
        filter: const PokemonFilter(types: {PokemonTypeId.fire}),
      );
      final list = (result as Ok<List<Pokemon>>).value;
      expect(list.map((p) => p.id), [4]);
    });

    test('surfaces a corrupt summary row as CacheFailure', () async {
      await dao.upsertSummaries([
        PokemonSummariesCompanion.insert(
          id: const Value(2),
          name: 'corrupt',
          nameNormalized: 'corrupt',
          primaryTypeId: 0,
          generationId: 1,
          height: 1,
          payloadJson: '{"corrupt":true}',
          updatedAt: nowMs(),
        ),
      ]);

      final result = await repo.findPokemon(sort: SortCriteria.numberAsc);

      expect((result as Err<List<Pokemon>>).failure, isA<CacheFailure>());
    });

    test('watchCachedSummaries maps the cache stream', () async {
      final first = await repo
          .watchCachedSummaries(sort: SortCriteria.numberAsc)
          .first;
      expect(first.map((p) => p.id), [1, 4]);
    });

    test(
      'watchCachedSummaries drops a corrupt row instead of erroring',
      () async {
        await dao.upsertSummaries([
          PokemonSummariesCompanion.insert(
            id: const Value(2),
            name: 'corrupt',
            nameNormalized: 'corrupt',
            primaryTypeId: 0,
            generationId: 1,
            height: 1,
            payloadJson: '{"corrupt":true}',
            updatedAt: nowMs(),
          ),
        ]);

        final first = await repo
            .watchCachedSummaries(sort: SortCriteria.numberAsc)
            .first;

        expect(first.map((p) => p.id), [1, 4]);
      },
    );
  });
}
