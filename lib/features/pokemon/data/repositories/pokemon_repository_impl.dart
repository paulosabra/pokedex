import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/database/cache_policy.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_dao.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_local_data_source.dart';
import 'package:pokedex/features/pokemon/data/datasources/pokemon_remote_data_source.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/cache_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/evolution_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/index_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_detail_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/type_effectiveness.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_page.dart';
import 'package:pokedex/features/pokemon/domain/entities/sort_criteria.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pokemon_repository_impl.g.dart';

/// Implementation of [PokemonRepository] (RN-02). Detail reads are cache-first
/// (fresh hits revalidate in the background, stale hits revalidate
/// synchronously) and degrade to stale/offline gracefully; list reads are
/// network-backed and seed the cache that powers offline search/filter/watch.
class PokemonRepositoryImpl implements PokemonRepository {
  /// Creates a [PokemonRepositoryImpl]. The clock is injectable for TTL tests.
  PokemonRepositoryImpl(
    this._remote,
    this._local,
    this._connectivity, [
    this._now = DateTime.now,
  ]);

  final PokemonRemoteDataSource _remote;
  final PokemonLocalDataSource _local;
  final Connectivity _connectivity;
  final DateTime Function() _now;

  @override
  Future<Result<PokemonPage>> getPokemonList({
    required int limit,
    required int offset,
  }) async {
    if (!await _isOnline()) return const Err(NetworkFailure());
    try {
      final page = await _remote.fetchPage(limit: limit, offset: offset);
      final ids = page.results
          .map((resource) => resource.idFromUrl)
          .whereType<int>()
          .toList();

      // An empty page (e.g. offset past the end) needs no type pre-warm or
      // per-id fan-out.
      if (ids.isEmpty) {
        return Ok(PokemonPage(hasMore: page.next != null));
      }

      final relations = await _ensureAllTypeRelations();
      final nowMs = _now().millisecondsSinceEpoch;
      final dtos = await Future.wait(ids.map(_remote.fetchPokemon));

      final items = <Pokemon>[];
      final companions = <PokemonSummariesCompanion>[];
      for (final dto in dtos) {
        final pokemon = pokemonFromDto(dto);
        items.add(pokemon);
        final mask = computeTypeEffectiveness(
          pokemon.types,
          relations,
        ).weaknessMask;
        companions.add(
          summaryToCompanion(
            pokemon,
            heightDecimetres: dto.height,
            weightHectograms: dto.weight,
            weaknessMask: mask,
            nowMs: nowMs,
          ),
        );
      }

      await _local.upsertSummaries(companions);
      return Ok(PokemonPage(items: items, hasMore: page.next != null));
    } on Failure catch (failure) {
      return Err(failure);
    }
  }

  @override
  Future<Result<PokemonDetail>> getPokemonDetail(int id) async {
    final row = await _local.readDetail(id);
    final online = await _isOnline();

    if (row != null) {
      final cached = _tryParse(() => detailFromRow(row));
      if (cached != null) {
        if (_isFresh(row.updatedAt, kPokemonCacheTtl)) {
          if (online) unawaited(_revalidateDetail(id));
          return Ok(cached);
        }
        // Stale: offline, serve the stale copy immediately rather than blocking
        // on a network call that can only time out. Online, revalidate now and
        // fall back to the stale copy on failure.
        if (!online) return Ok(cached);
        try {
          return Ok(await _composeDetail(id));
        } on Failure {
          return Ok(cached);
        }
      }
      // Corrupt payload: offline can't recover; online treats it as a miss.
      if (!online) return const Err(CacheFailure());
    } else if (!online) {
      return const Err(NetworkFailure());
    }

    try {
      return Ok(await _composeDetail(id));
    } on Failure catch (failure) {
      // A 404 here means the index promised a Pokémon the detail endpoint
      // disagrees with — drop the ghost row so subsequent searches don't
      // re-surface it.
      if (failure is NotFoundFailure) {
        try {
          await _local.evictIndexRow(id);
        } on Exception {
          // Best-effort cleanup; never poison the user-facing error.
        }
      }
      return Err(failure);
    }
  }

  @override
  Future<Result<EvolutionChain>> getEvolutionChain(int id) async {
    // The chain id lives on the species (not cached separately), so resolving
    // it needs the network; the chain itself is then served cache-first.
    if (!await _isOnline()) return const Err(NetworkFailure());
    try {
      final species = await _remote.fetchSpecies(id);
      final chainId = species.evolutionChain.idFromUrl;
      if (chainId == null) return const Err(NotFoundFailure());

      final row = await _local.readEvolutionChain(chainId);
      if (row != null && _isFresh(row.updatedAt, kPokemonCacheTtl)) {
        final cached = _tryParse(() => evolutionFromRow(row));
        if (cached != null) return Ok(cached);
      }

      final dto = await _remote.fetchEvolutionChain(chainId);
      final chain = evolutionChainFromDto(dto);
      await _local.upsertEvolutionChain(
        evolutionToCompanion(
          chainId,
          chain,
          nowMs: _now().millisecondsSinceEpoch,
        ),
      );
      return Ok(chain);
    } on Failure catch (failure) {
      return Err(failure);
    }
  }

  @override
  Future<Result<List<Pokemon>>> findPokemon({
    required SortCriteria sort,
    String? query,
    PokemonFilter? filter,
  }) async {
    // Type/weakness/height/weight predicates live on PokemonSummaries (the
    // index has no type or measurement columns), so when ANY of those axes
    // are active we keep the existing summary-only intersection. Pure
    // search and generation/numberRange queries can read the full index.
    if (_filterRequiresSummaries(filter)) {
      return _readSummaries(
        _local.querySummaries(sort: sort, query: query, filter: filter),
      );
    }

    try {
      final indexRows = await _local.queryIndex(sort: sort, query: query);
      if (indexRows.isEmpty) {
        // Either the index hasn't loaded yet OR the search returned nothing.
        // Fall back to summary search so a user's pre-index typing isn't
        // empty by definition; if both are empty, the result is empty.
        return _readSummaries(
          _local.querySummaries(sort: sort, query: query, filter: filter),
        );
      }
      final out = <Pokemon>[];
      for (final row in indexRows) {
        if (!_indexRowSatisfies(row, filter)) continue;
        final summary = await _local.readSummary(row.id);
        if (summary != null) {
          final hydrated = _tryParse(() => pokemonFromRow(summary));
          if (hydrated != null) {
            out.add(hydrated);
            continue;
          }
        }
        out.add(skeletonFromIndexRow(row));
      }
      return Ok(out);
    } on Exception {
      // Drift reads throw `Exception` subtypes on failure; programmer errors
      // (`TypeError`, `RangeError`) should propagate so they're caught in
      // testing rather than masked as a user-facing cache miss.
      return const Err(CacheFailure());
    }
  }

  @override
  Stream<List<Pokemon>> watchCachedSummaries({
    required SortCriteria sort,
    PokemonFilter? filter,
  }) => _local
      .watchSummaries(sort: sort, filter: filter)
      .map(
        // Drop a corrupt row rather than erroring the whole stream; a stream of
        // cache state should survive one bad payload.
        (rows) => rows
            .map((row) => _tryParse(() => pokemonFromRow(row)))
            .whereType<Pokemon>()
            .toList(),
      );

  @override
  Future<IndexState> readIndexState() async {
    final bounds = await _local.readIndexBounds();
    if (bounds == null) return IndexState.idle();
    final generationIds = await _local.listGenerationIds();
    final indexedAt = await _local.readIndexSnapshotAt();
    final isFresh = indexedAt != null && _isFresh(indexedAt, kPokemonIndexTtl);
    return IndexState(
      status: isFresh ? IndexStatus.ready : IndexStatus.stale,
      minId: bounds.minId,
      maxId: bounds.maxId,
      totalCount: bounds.totalCount,
      generationIds: generationIds.toSet(),
      indexedAt: indexedAt,
    );
  }

  @override
  Future<Result<IndexState>> refreshIndex() async {
    if (!await _isOnline()) return const Err(NetworkFailure());
    try {
      final response = await _remote.fetchIndex(limit: _indexFetchLimit);
      final nowMs = _now().millisecondsSinceEpoch;
      final companions = indexFromResponse(response, nowMs: nowMs);
      if (companions.isNotEmpty) {
        await _local.upsertIndex(companions);
      }
      return Ok(await readIndexState());
    } on Failure catch (failure) {
      return Err(failure);
    }
  }

  @override
  Future<List<int>> listGenerationMembers(int generationId) =>
      _local.listGenerationMembers(generationId);

  @override
  Future<List<int>> listMissingSummaryIds({int? limit}) =>
      _local.listMissingSummaryIds(limit: limit);

  @override
  Future<void> evictIndexEntry(int id) => _local.evictIndexRow(id);

  @override
  Future<Result<void>> hydrateSummary(int id) async {
    if (!await _isOnline()) return const Err(NetworkFailure());
    try {
      final dto = await _remote.fetchPokemon(id);
      final pokemon = pokemonFromDto(dto);
      final relations = await _ensureAllTypeRelations();
      final mask = computeTypeEffectiveness(
        pokemon.types,
        relations,
      ).weaknessMask;
      await _local.upsertSummaries([
        summaryToCompanion(
          pokemon,
          heightDecimetres: dto.height,
          weightHectograms: dto.weight,
          weaknessMask: mask,
          nowMs: _now().millisecondsSinceEpoch,
        ),
      ]);
      return const Ok(null);
    } on Failure catch (failure) {
      return Err(failure);
    }
  }

  /// Upper bound for the single `/pokemon` request that builds the index. The
  /// PokéAPI is well above this today (~1300 rows); the round number leaves
  /// headroom for the inevitable Gen X additions.
  static const int _indexFetchLimit = 100000;

  bool _filterRequiresSummaries(PokemonFilter? filter) {
    if (filter == null) return false;
    return filter.types.isNotEmpty ||
        filter.weaknesses.isNotEmpty ||
        filter.height != null ||
        filter.weight != null;
  }

  bool _indexRowSatisfies(PokemonIndexRow row, PokemonFilter? filter) {
    if (filter == null) return true;
    final genId = filter.generationId;
    if (genId != null && row.generationId != genId) return false;
    final range = filter.numberRange;
    if (range != null && (row.id < range.min || row.id > range.max)) {
      return false;
    }
    return true;
  }

  Future<Result<List<Pokemon>>> _readSummaries(
    Future<List<PokemonSummaryRow>> rowsFuture,
  ) async {
    try {
      final rows = await rowsFuture;
      return Ok(rows.map(pokemonFromRow).toList());
    } on Object {
      // Any decode failure (bad JSON or wrong shape) means a corrupt cache.
      return const Err(CacheFailure());
    }
  }

  /// Composes a fresh detail from up to 4 endpoints, caching only when every
  /// part succeeded so a degraded detail is never frozen in the cache.
  Future<PokemonDetail> _composeDetail(int id) async {
    final pokemonDto = await _remote.fetchPokemon(id); // mandatory
    final pokemon = pokemonFromDto(pokemonDto);
    final nowMs = _now().millisecondsSinceEpoch;
    var complete = true;

    final species = await _tryFetch(
      () => _remote.fetchSpecies(id),
      () => complete = false,
    );

    final relations = <PokemonTypeId, DamageRelationsDto>{};
    for (final type in pokemon.types) {
      final relation = await _tryFetch(
        () => _relationFor(type, nowMs),
        () => complete = false,
      );
      if (relation != null) relations[type] = relation;
    }
    final effectiveness = computeTypeEffectiveness(pokemon.types, relations);

    final encounters =
        await _tryFetch(
          () => _remote.fetchEncounters(id),
          () => complete = false,
        ) ??
        const <LocationAreaEncounterDto>[];

    final detail = pokemonDetailFromDtos(
      pokemon: pokemonDto,
      species: species,
      effectiveness: effectiveness,
      encounters: encounters,
    );

    if (complete) {
      // Best-effort: a cache-write I/O failure must not discard a detail the
      // caller already paid the network for. Scoped to Exception so a mapper
      // bug (an Error) still surfaces instead of being silently buried.
      try {
        await _local.upsertDetail(detailToCompanion(detail, nowMs: nowMs));
      } on Exception {
        // Swallow: the composed detail is returned regardless.
      }
    }
    return detail;
  }

  /// Reads a single type's damage relations cache-first (long static TTL).
  Future<DamageRelationsDto> _relationFor(PokemonTypeId type, int nowMs) async {
    final row = await _local.readTypeRelation(type.index);
    if (row != null && _isFresh(row.updatedAt, kStaticDataTtl)) {
      return damageRelationsFromRow(row);
    }
    final dto = await _remote.fetchType(pokeApiTypeIds[type]!);
    await _local.upsertTypeRelation(
      typeRelationToCompanion(type, dto.damageRelations, nowMs: nowMs),
    );
    return dto.damageRelations;
  }

  /// Pre-warms and returns all 18 type relations so summary weakness masks are
  /// computable for any page (RF-15).
  Future<Map<PokemonTypeId, DamageRelationsDto>>
  _ensureAllTypeRelations() async {
    final nowMs = _now().millisecondsSinceEpoch;
    final relations = <PokemonTypeId, DamageRelationsDto>{};
    for (final type in PokemonTypeId.values) {
      relations[type] = await _relationFor(type, nowMs);
    }
    return relations;
  }

  Future<void> _revalidateDetail(int id) async {
    try {
      await _composeDetail(id);
    } on Object {
      // The caller already has data; staleness surfacing is the UI epic's job.
    }
  }

  Future<bool> _isOnline() => isOnline(_connectivity);

  bool _isFresh(int updatedAtMs, Duration ttl) =>
      _now().millisecondsSinceEpoch - updatedAtMs <= ttl.inMilliseconds;

  T? _tryParse<T>(T Function() parse) {
    try {
      return parse();
    } on Object {
      // Bad JSON (FormatException) or a valid-JSON wrong shape (TypeError /
      // CheckedFromJsonException) both mean the cached payload is corrupt.
      return null;
    }
  }

  Future<T?> _tryFetch<T>(
    Future<T> Function() fetch,
    void Function() onFailure,
  ) async {
    try {
      return await fetch();
    } on Failure {
      onFailure();
      return null;
    }
  }
}

/// Provides the [PokemonRepository], returning the abstract type so callers
/// (use cases) depend on the interface (DIP).
@riverpod
PokemonRepository pokemonRepository(Ref ref) => PokemonRepositoryImpl(
  ref.watch(pokemonRemoteDataSourceProvider),
  ref.watch(pokemonLocalDataSourceProvider),
  ref.watch(connectivityProvider),
);
