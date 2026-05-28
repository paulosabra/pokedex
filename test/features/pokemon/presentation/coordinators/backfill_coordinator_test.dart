import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/network/connectivity_provider.dart';
import 'package:pokedex/features/pokemon/data/repositories/pokemon_repository_impl.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/domain/repositories/pokemon_repository.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/backfill_coordinator.dart';

class _MockRepository extends Mock implements PokemonRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockRepository repository;
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> connectivityChanges;
  late ProviderContainer container;

  void goOnline() => when(
    () => connectivity.checkConnectivity(),
  ).thenAnswer((_) async => [ConnectivityResult.wifi]);

  void goOffline() => when(
    () => connectivity.checkConnectivity(),
  ).thenAnswer((_) async => [ConnectivityResult.none]);

  /// Seeds the index coordinator with a ready state so the backfill is not
  /// gated out at the very first guard.
  void seedIndexReady({int totalCount = 5}) {
    when(repository.readIndexState).thenAnswer(
      (_) async => IndexState(
        status: IndexStatus.ready,
        minId: 1,
        maxId: totalCount,
        totalCount: totalCount,
      ),
    );
  }

  setUp(() {
    repository = _MockRepository();
    connectivity = _MockConnectivity();
    connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();

    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => connectivityChanges.stream);

    goOnline();
    when(
      () => repository.hydrateSummary(any()),
    ).thenAnswer((_) async => const Ok(null));

    container = ProviderContainer(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(repository),
        connectivityProvider.overrideWithValue(connectivity),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await connectivityChanges.close();
    });
  });

  group('BackfillCoordinator', () {
    test('starts only when the index is ready/stale', () async {
      when(
        repository.readIndexState,
      ).thenAnswer((_) async => IndexState.idle());

      // Initial read so the coordinator's onConnectivityChanged listener
      // subscribes before we start.
      container.read(backfillCoordinatorProvider);

      await container.read(backfillCoordinatorProvider.notifier).start();

      verifyNever(
        () => repository.listMissingSummaryIds(
          limit: any(named: 'limit'),
        ),
      );
      final progress = container.read(backfillCoordinatorProvider);
      expect(progress.isRunning, isFalse);
    });

    test('drains all missing ids and lands hydrated == total', () async {
      seedIndexReady(totalCount: 3);
      var firstCall = true;
      when(
        () => repository.listMissingSummaryIds(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        if (firstCall) {
          firstCall = false;
          return [1, 2, 3];
        }
        return <int>[];
      });
      when(repository.listMissingSummaryIds).thenAnswer((_) async => [1, 2, 3]);

      container.read(backfillCoordinatorProvider);
      await container.read(backfillCoordinatorProvider.notifier).start();

      final progress = container.read(backfillCoordinatorProvider);
      expect(progress.total, 3);
      expect(progress.hydrated, 3);
      expect(progress.isRunning, isFalse);
      expect(progress.isComplete, isTrue);
      verify(() => repository.hydrateSummary(1)).called(1);
      verify(() => repository.hydrateSummary(2)).called(1);
      verify(() => repository.hydrateSummary(3)).called(1);
    });

    test(
      '404 evicts the index row and decrements total (not the error budget)',
      () async {
        seedIndexReady(totalCount: 3);
        var firstCall = true;
        when(
          () => repository.listMissingSummaryIds(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          if (firstCall) {
            firstCall = false;
            return [1, 2, 3];
          }
          return <int>[];
        });
        when(
          repository.listMissingSummaryIds,
        ).thenAnswer((_) async => [1, 2, 3]);
        when(
          () => repository.hydrateSummary(2),
        ).thenAnswer((_) async => const Err(NotFoundFailure()));
        when(() => repository.evictIndexEntry(any())).thenAnswer((_) async {});

        container.read(backfillCoordinatorProvider);
        await container.read(backfillCoordinatorProvider.notifier).start();

        verify(() => repository.evictIndexEntry(2)).called(1);
        final progress = container.read(backfillCoordinatorProvider);
        // 3 - 1 evicted = 2; both remaining ids hydrated; not halted.
        expect(progress.total, 2);
        expect(progress.hydrated, 2);
        expect(progress.isHaltedThisSession, isFalse);
        expect(progress.isComplete, isTrue);
      },
    );

    test(
      'halts the session after 5 consecutive non-404 errors',
      () async {
        seedIndexReady(totalCount: 10);
        var firstCall = true;
        when(
          () => repository.listMissingSummaryIds(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          if (firstCall) {
            firstCall = false;
            return [1, 2, 3, 4, 5, 6, 7, 8];
          }
          return <int>[];
        });
        when(
          repository.listMissingSummaryIds,
        ).thenAnswer((_) async => [1, 2, 3, 4, 5, 6, 7, 8]);
        // All hydrates fail with a server error — the budget burns down.
        when(
          () => repository.hydrateSummary(any()),
        ).thenAnswer((_) async => const Err(ServerFailure()));

        container.read(backfillCoordinatorProvider);
        await container.read(backfillCoordinatorProvider.notifier).start();

        final progress = container.read(backfillCoordinatorProvider);
        expect(progress.isHaltedThisSession, isTrue);
        expect(progress.isRunning, isFalse);
        // Baseline at-start: total (10) - missing (8) = 2 already hydrated.
        // Every hydration in this drain failed, so the baseline stands.
        expect(progress.hydrated, 2);
      },
    );

    test('a successful hydration after errors resets the counter', () async {
      seedIndexReady(totalCount: 6);
      var firstCall = true;
      when(
        () => repository.listMissingSummaryIds(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        if (firstCall) {
          firstCall = false;
          return [1, 2, 3, 4, 5, 6];
        }
        return <int>[];
      });
      when(
        repository.listMissingSummaryIds,
      ).thenAnswer((_) async => [1, 2, 3, 4, 5, 6]);

      // Fail the first 3, then 3 successes. Budget never hits 5.
      final failingIds = {1, 2, 3};
      when(() => repository.hydrateSummary(any())).thenAnswer((inv) async {
        final id = inv.positionalArguments.first as int;
        if (failingIds.contains(id)) return const Err(ServerFailure());
        return const Ok(null);
      });

      container.read(backfillCoordinatorProvider);
      await container.read(backfillCoordinatorProvider.notifier).start();

      final progress = container.read(backfillCoordinatorProvider);
      expect(progress.isHaltedThisSession, isFalse);
      expect(progress.hydrated, 3);
    });

    test('pauses on offline and exits with isRunning false', () async {
      seedIndexReady(totalCount: 3);
      when(repository.listMissingSummaryIds).thenAnswer((_) async => [1, 2, 3]);
      // Go offline AFTER the initial readIndexState (in the build path).
      // We rig listMissingSummaryIds to not be called by going offline first.
      goOffline();

      container.read(backfillCoordinatorProvider);
      await container.read(backfillCoordinatorProvider.notifier).start();

      verifyNever(() => repository.hydrateSummary(any()));
      expect(container.read(backfillCoordinatorProvider).isRunning, isFalse);
    });
  });
}
