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
import 'package:pokedex/features/pokemon/presentation/coordinators/index_coordinator.dart';

class _MockRepository extends Mock implements PokemonRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockRepository repository;
  late _MockConnectivity connectivity;
  late ProviderContainer container;

  void goOnline() => when(
    () => connectivity.checkConnectivity(),
  ).thenAnswer((_) async => [ConnectivityResult.wifi]);

  void goOffline() => when(
    () => connectivity.checkConnectivity(),
  ).thenAnswer((_) async => [ConnectivityResult.none]);

  setUp(() {
    repository = _MockRepository();
    connectivity = _MockConnectivity();
    goOnline();
    when(repository.readIndexState).thenAnswer((_) async => IndexState.idle());

    container = ProviderContainer(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(repository),
        connectivityProvider.overrideWithValue(connectivity),
      ],
    );
    addTearDown(container.dispose);
  });

  group('IndexCoordinator', () {
    test('build() hydrates from the cached state (idle if empty)', () async {
      final state = await container.read(indexCoordinatorProvider.future);
      expect(state.status, IndexStatus.idle);
      verify(repository.readIndexState).called(1);
      verifyNever(repository.refreshIndex);
    });

    test('loadIfNeeded fires when idle + online, lands ready', () async {
      const fresh = IndexState(
        status: IndexStatus.ready,
        minId: 1,
        maxId: 1025,
        totalCount: 1025,
      );
      when(repository.refreshIndex).thenAnswer((_) async => const Ok(fresh));

      await container.read(indexCoordinatorProvider.future);
      await container.read(indexCoordinatorProvider.notifier).loadIfNeeded();

      final state = container.read(indexCoordinatorProvider).value;
      expect(state!.status, IndexStatus.ready);
      verify(repository.refreshIndex).called(1);
    });

    test(
      'loadIfNeeded is single-flight (concurrent calls coalesce)',
      () async {
        final completer = Completer<Result<IndexState>>();
        when(repository.refreshIndex).thenAnswer((_) => completer.future);

        await container.read(indexCoordinatorProvider.future);
        final notifier = container.read(indexCoordinatorProvider.notifier);

        // Fire three loads in parallel — only one network call should land.
        final futures = [
          notifier.loadIfNeeded(),
          notifier.loadIfNeeded(),
          notifier.loadIfNeeded(),
        ];
        completer.complete(
          const Ok(IndexState(status: IndexStatus.ready, totalCount: 1)),
        );
        await Future.wait(futures);

        verify(repository.refreshIndex).called(1);
      },
    );

    test(
      'loadIfNeeded is a no-op when already ready (within TTL)',
      () async {
        when(repository.readIndexState).thenAnswer(
          (_) async => const IndexState(
            status: IndexStatus.ready,
            totalCount: 1025,
          ),
        );

        await container.read(indexCoordinatorProvider.future);
        await container.read(indexCoordinatorProvider.notifier).loadIfNeeded();

        verifyNever(repository.refreshIndex);
      },
    );

    test('loadIfNeeded from idle + offline lands in failed', () async {
      goOffline();

      await container.read(indexCoordinatorProvider.future);
      await container.read(indexCoordinatorProvider.notifier).loadIfNeeded();

      final state = container.read(indexCoordinatorProvider).value!;
      expect(state.status, IndexStatus.failed);
      expect(state.lastError, isA<NetworkFailure>());
      verifyNever(repository.refreshIndex);
    });

    test(
      'loadIfNeeded from stale + offline keeps serving (status stays stale)',
      () async {
        when(repository.readIndexState).thenAnswer(
          (_) async => const IndexState(
            status: IndexStatus.stale,
            minId: 1,
            maxId: 1025,
            totalCount: 1025,
          ),
        );
        goOffline();

        await container.read(indexCoordinatorProvider.future);
        await container.read(indexCoordinatorProvider.notifier).loadIfNeeded();

        final state = container.read(indexCoordinatorProvider).value!;
        expect(state.status, IndexStatus.stale);
        expect(state.totalCount, 1025);
        expect(state.lastError, isA<NetworkFailure>());
      },
    );

    test(
      'refresh + offline from ready keeps status ready '
      "— offline doesn't demote a fresh cache (regression C3)",
      () async {
        when(repository.readIndexState).thenAnswer(
          (_) async => const IndexState(
            status: IndexStatus.ready,
            minId: 1,
            maxId: 1025,
            totalCount: 1025,
          ),
        );

        await container.read(indexCoordinatorProvider.future);
        goOffline();
        await container.read(indexCoordinatorProvider.notifier).refresh();

        final state = container.read(indexCoordinatorProvider).value!;
        expect(state.status, IndexStatus.ready);
        expect(state.lastError, isA<NetworkFailure>());
        expect(state.totalCount, 1025);
        verifyNever(repository.refreshIndex);
      },
    );

    test('loadIfNeeded on remote failure surfaces failed', () async {
      when(
        repository.refreshIndex,
      ).thenAnswer((_) async => const Err(ServerFailure()));

      await container.read(indexCoordinatorProvider.future);
      await container.read(indexCoordinatorProvider.notifier).loadIfNeeded();

      final state = container.read(indexCoordinatorProvider).value!;
      expect(state.status, IndexStatus.failed);
      expect(state.lastError, isA<ServerFailure>());
    });

    test('refresh() force-fires even when ready', () async {
      when(repository.readIndexState).thenAnswer(
        (_) async => const IndexState(
          status: IndexStatus.ready,
          totalCount: 100,
        ),
      );
      when(repository.refreshIndex).thenAnswer(
        (_) async => const Ok(
          IndexState(status: IndexStatus.ready, totalCount: 200),
        ),
      );

      await container.read(indexCoordinatorProvider.future);
      await container.read(indexCoordinatorProvider.notifier).refresh();

      final state = container.read(indexCoordinatorProvider).value!;
      expect(state.totalCount, 200);
      verify(repository.refreshIndex).called(1);
    });
  });
}
