import 'dart:async';

import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'index_coordinator.g.dart';

/// Orchestrates the lifecycle of the National-Dex index — first-load,
/// refresh, single-flight, offline failure — and exposes the resulting
/// `IndexState` for the four discovery surfaces (Search, Sort, Filters,
/// Generations) to read.
///
/// State transitions (sticky-keep semantics):
///
/// | From    | Trigger                                  | To       |
/// |---------|------------------------------------------|----------|
/// | idle    | `loadIfNeeded()` + online                | loading  |
/// | idle    | `loadIfNeeded()` + offline + no cache    | failed   |
/// | loading | fetch success                            | ready    |
/// | loading | fetch failure                            | failed   |
/// | ready   | TTL expiry on next `loadIfNeeded()`      | stale    |
/// | stale   | `refresh()` success                      | ready    |
/// | stale   | `refresh()` failure                      | stale    |
/// | failed  | `refresh()` success                      | ready    |
///
/// `keepAlive: true` so the index snapshot survives provider rebuilds (a
/// sheet open/close must not refetch ~200 KB).
@Riverpod(keepAlive: true)
class IndexCoordinator extends _$IndexCoordinator {
  Future<void>? _inFlight;

  @override
  Future<IndexState> build() async {
    // Hydrate from cache only — the network call waits for the list VM to
    // signal that page-0 returned so it doesn't race the page's 24-detail
    // fan-out on Dio's connection pool.
    return ref.read(pokemonRepositoryProvider).readIndexState();
  }

  /// Fires a fetch only when the state needs one (idle / stale / failed),
  /// and only when online. Concurrent callers join the same in-flight
  /// future — coalescing protects PokeAPI from a thundering herd at app
  /// launch (Generations sheet + ViewModel + Filters slider all wake
  /// roughly together).
  Future<void> loadIfNeeded() async {
    if (_inFlight != null) return _inFlight;
    final current = state.value ?? IndexState.idle();
    final needsLoad =
        current.status == IndexStatus.idle ||
        current.status == IndexStatus.stale ||
        current.status == IndexStatus.failed;
    if (!needsLoad) return;

    final future = _runFetch(current);
    _inFlight = future;
    try {
      await future;
    } finally {
      _inFlight = null;
    }
  }

  /// User-driven refresh (pull-to-refresh, "try again" from a failed
  /// surface). Bypasses the freshness check — always fires when online.
  Future<void> refresh() async {
    if (_inFlight != null) return _inFlight;
    final current = state.value ?? IndexState.idle();
    final future = _runFetch(current);
    _inFlight = future;
    try {
      await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _runFetch(IndexState previous) async {
    if (!await _isOnline()) {
      // Offline keeps serving whatever cache we have. A fresh `ready` cache
      // stays `ready` (TTL hasn't elapsed — it's just a failed refresh);
      // `stale` keeps serving stale; `idle`/`failed` (no usable cache)
      // surfaces as `failed` so the UI can render fallbacks.
      switch (previous.status) {
        case IndexStatus.ready:
        case IndexStatus.stale:
          state = AsyncData(
            previous.copyWith(lastError: const NetworkFailure()),
          );
        case IndexStatus.idle:
        case IndexStatus.failed:
        case IndexStatus.loading:
          state = AsyncData(
            previous.copyWith(
              status: IndexStatus.failed,
              lastError: const NetworkFailure(),
            ),
          );
      }
      return;
    }
    state = AsyncData(previous.copyWith(status: IndexStatus.loading));
    final result = await ref.read(pokemonRepositoryProvider).refreshIndex();
    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
      case Err(:final failure):
        // A refresh failure from `stale`/`ready` keeps serving the cache;
        // from `idle` or `failed` it surfaces as failed so the UI can
        // degrade to fallbacks.
        final fallback =
            previous.status == IndexStatus.idle ||
                previous.status == IndexStatus.failed
            ? IndexStatus.failed
            : IndexStatus.stale;
        state = AsyncData(
          previous.copyWith(status: fallback, lastError: failure),
        );
    }
  }

  Future<bool> _isOnline() => isOnline(ref.read(connectivityProvider));
}
