import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/backfill_progress.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/index_coordinator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backfill_coordinator.g.dart';

/// Paces the hydration of `PokemonIndex - PokemonSummaries` so the user
/// experiences "Filtering across X of Y Pokémon" climbing toward `Y`
/// without ever spiking the network or jamming the SQLite worker.
///
/// Gating:
///   - the [`IndexCoordinator`] is in [IndexStatus.ready] or
///     [IndexStatus.stale] (i.e. a cache exists; we know `total`)
///   - the device is online
///   - the per-session error budget hasn't been exhausted
///
/// Concurrency / safety:
///   - up to [_concurrent] in-flight `hydrateSummary` calls
///   - halts for the session after [_maxConsecutiveErrors] non-404 errors
///   - resumes within one connectivity tick of going back online
///
/// `keepAlive: true` so progress survives provider rebuilds (sheet open
/// must not reset the header).
@Riverpod(keepAlive: true)
class BackfillCoordinator extends _$BackfillCoordinator {
  /// Concurrency cap — kept smaller on web because the browser fetch queue
  /// throttles harder and the IndexedDB worker can lag on bursts.
  static const int _concurrent = kIsWeb ? 4 : 8;

  /// How many ids the drain pulls per chunk. Big enough to amortize the
  /// `listMissingSummaryIds` round-trip; small enough that a connectivity
  /// drop pauses promptly at chunk boundaries.
  static const int _chunkSize = 200;

  /// Session error budget — see [`BackfillProgress.isHaltedThisSession`].
  static const int _maxConsecutiveErrors = 5;

  /// In-flight drain, used to make [start] single-flight.
  Future<void>? _draining;
  int _consecutiveErrors = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  BackfillProgress build() {
    // Auto-resume on reconnect (acceptance: resumes within 2s of online).
    _connectivitySub = ref
        .read(connectivityProvider)
        .onConnectivityChanged
        .listen((results) {
          final online = results.any((r) => r != ConnectivityResult.none);
          if (online) unawaited(start());
        });
    ref.onDispose(() => _connectivitySub?.cancel());
    return BackfillProgress.idle();
  }

  /// Idempotent entry point. Reads the current [IndexState], picks up where
  /// it left off, and runs until drained / offline / halted.
  Future<void> start() async {
    if (_draining != null) return _draining;
    if (state.isHaltedThisSession) return;
    _draining = _drain();
    try {
      await _draining;
    } finally {
      _draining = null;
    }
  }

  Future<void> _drain() async {
    final index = await ref.read(indexCoordinatorProvider.future);
    if (index.status != IndexStatus.ready &&
        index.status != IndexStatus.stale) {
      // No cache to drive the drain — wait for the index to land.
      return;
    }
    if (!await _isOnline()) return;

    final repo = ref.read(pokemonRepositoryProvider);
    final total = index.totalCount ?? 0;
    if (total == 0) return;

    final missingAtStart = await repo.listMissingSummaryIds();
    state = state.copyWith(
      isRunning: true,
      total: total,
      hydrated: total - missingAtStart.length,
    );

    while (true) {
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        state = state.copyWith(
          isRunning: false,
          isHaltedThisSession: true,
        );
        return;
      }
      if (!await _isOnline()) {
        state = state.copyWith(isRunning: false);
        return;
      }
      final chunk = await repo.listMissingSummaryIds(limit: _chunkSize);
      if (chunk.isEmpty) {
        state = state.copyWith(isRunning: false);
        return;
      }
      for (var i = 0; i < chunk.length; i += _concurrent) {
        final end = (i + _concurrent).clamp(0, chunk.length);
        await Future.wait(chunk.sublist(i, end).map(_hydrateOne));
        if (_consecutiveErrors >= _maxConsecutiveErrors) break;
        if (!await _isOnline()) break;
      }
    }
  }

  Future<void> _hydrateOne(int id) async {
    final repo = ref.read(pokemonRepositoryProvider);
    final result = await repo.hydrateSummary(id);
    switch (result) {
      case Ok():
        _consecutiveErrors = 0;
        state = state.copyWith(hydrated: state.hydrated + 1);
      case Err(:final failure):
        if (failure is NotFoundFailure) {
          // 404: the row was published in the index but the detail endpoint
          // disagrees. Evict so subsequent searches don't surface it.
          await repo.evictIndexEntry(id);
          final current = state.total ?? 1;
          state = state.copyWith(total: (current - 1).clamp(0, current));
          // Not counted toward the error budget — eviction is the success
          // path for this case.
        } else {
          _consecutiveErrors += 1;
        }
    }
  }

  Future<bool> _isOnline() => isOnline(ref.read(connectivityProvider));
}
