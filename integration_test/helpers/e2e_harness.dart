import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/app/app.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/core/network/dio_client.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/backfill_coordinator.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/backfill_progress.dart';

import 'fake_connectivity.dart';
import 'fake_poke_api.dart';
import 'in_memory_database.dart';

/// Boots the real [PokedexApp] graph against in-memory I/O for E2E flows.
///
/// Only the three leaf I/O providers are overridden — the SQLite database
/// (in-memory Drift), the Dio client (the [FakePokeApi] adapter), and
/// connectivity (always online). Everything above them (remote data source,
/// cache-first repository, use cases, coordinators, view models, router) runs
/// unmodified, which is what makes this an integration test rather than a
/// widget test.
class E2EHarness {
  /// Creates a harness over a simulated catalogue of [total] Pokémon.
  E2EHarness({int total = 48}) : api = FakePokeApi(total: total);

  /// The fake PokéAPI; tests read [FakePokeApi.nameOf] for stable assertions.
  final FakePokeApi api;

  /// The in-memory database backing the cache-first repository.
  final AppDatabase database = AppDatabase.forTesting(inMemoryExecutor());

  /// Pumps the app on a compact (single-column) surface and settles the first
  /// page load + index fetch.
  Future<void> pumpApp(WidgetTester tester) async {
    // Pin DPR so the 420px surface maps 1:1 to logical pixels (compact, so the
    // list renders as a single column and master-detail stays single-pane).
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dioProvider.overrideWithValue(api.buildDio()),
          connectivityProvider.overrideWithValue(FakeOnlineConnectivity()),
          // The detail backfill drains the index in the background; stub it so
          // its unbounded fan-out never races `pumpAndSettle`. (Search still
          // works off the index/summary cache without it.)
          backfillCoordinatorProvider.overrideWith(
            _NoopBackfillCoordinator.new,
          ),
        ],
        child: const PokedexApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// A no-op [BackfillCoordinator] that never drains, so the paced catalogue
/// hydration cannot race the test's `pumpAndSettle`.
class _NoopBackfillCoordinator extends BackfillCoordinator {
  @override
  BackfillProgress build() => BackfillProgress.idle();

  @override
  Future<void> start() async {}
}
