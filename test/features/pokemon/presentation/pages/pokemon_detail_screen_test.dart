import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/core/observability/observability_providers.dart';
import 'package:pokedex/core/ui/components/shimmer_box.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_pokemon_detail.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_detail_screen.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/about_tab.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/evolution_tab.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/stats_tab.dart';

import '../../../../helpers/recording_observability.dart';
import '../fixtures/eevee_evolution_chain.dart';
import '../fixtures/pokemon_detail_builder.dart';

class _MockGetPokemonDetail extends Mock implements GetPokemonDetail {}

class _MockGetEvolutionChain extends Mock implements GetEvolutionChain {}

class _Harness {
  _Harness({required this.getDetail, required this.getChain});
  final _MockGetPokemonDetail getDetail;
  final _MockGetEvolutionChain getChain;
}

_Harness _makeHarness() {
  final harness = _Harness(
    getDetail: _MockGetPokemonDetail(),
    getChain: _MockGetEvolutionChain(),
  );
  when(
    () => harness.getDetail.call(any()),
  ).thenAnswer((_) async => Ok(bulbasaurDetail()));
  when(
    () => harness.getChain.call(any()),
  ).thenAnswer((_) async => Ok(bulbasaurEvolutionChain()));
  return harness;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _Harness harness,
  int id = 1,
  RecordingAnalytics? analytics,
  Size size = const Size(420, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        getPokemonDetailProvider.overrideWithValue(harness.getDetail),
        getEvolutionChainProvider.overrideWithValue(harness.getChain),
        if (analytics != null)
          analyticsServiceProvider.overrideWithValue(analytics),
      ],
      child: MaterialApp(home: PokemonDetailScreen(id: id)),
    ),
  );
}

void main() {
  group('PokemonDetailScreen', () {
    testWidgets('renders the three tabs after the detail loads', (
      tester,
    ) async {
      final harness = _makeHarness();
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      expect(find.byType(AboutTab), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Evolution'), findsOneWidget);
    });

    testWidgets('tapping the Stats tab swaps to StatsTab', (tester) async {
      final harness = _makeHarness();
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.byType(StatsTab), findsOneWidget);
      expect(find.byType(AboutTab), findsNothing);
    });

    testWidgets('tapping the Evolution tab swaps to EvolutionTab', (
      tester,
    ) async {
      final harness = _makeHarness();
      await _pumpScreen(tester, harness: harness);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Evolution'));
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionTab), findsOneWidget);
    });

    testWidgets('deep-link smoke: PokemonDetailScreen mounts at /pokemon/:id', (
      tester,
    ) async {
      final harness = _makeHarness();
      await _pumpScreen(tester, harness: harness, id: 25);
      await tester.pumpAndSettle();

      expect(find.byType(PokemonDetailScreen), findsOneWidget);
    });

    testWidgets(
      'shows the shimmer skeleton while the detail is loading',
      (tester) async {
        final harness = _makeHarness();
        when(() => harness.getDetail.call(any())).thenAnswer(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => Ok(bulbasaurDetail()),
          ),
        );

        await _pumpScreen(tester, harness: harness);
        // First frame after pumpWidget — still loading. The shimmer wrapper
        // and at least one skeleton block stand in for the prior spinner.
        expect(find.byType(AppShimmer), findsOneWidget);
        expect(find.byType(SkeletonBox), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'offline-no-cache shows Back CTA (resolved blocker 4)',
      (tester) async {
        final harness = _makeHarness();
        when(
          () => harness.getDetail.call(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        expect(
          find.text('You are offline and this Pokémon is not cached.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(ElevatedButton, 'Back'), findsOneWidget);
      },
    );

    testWidgets(
      'generic failure renders the back CTA with a fallback message',
      (tester) async {
        final harness = _makeHarness();
        when(
          () => harness.getDetail.call(any()),
        ).thenAnswer((_) async => const Err(ServerFailure()));

        await _pumpScreen(tester, harness: harness);
        await tester.pumpAndSettle();

        expect(find.text('Could not load this Pokémon.'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Back'), findsOneWidget);
      },
    );

    testWidgets(
      'Back CTA on deep-link with no history routes to / '
      '(resolved test-quality BLOCKER-2)',
      (tester) async {
        final harness = _makeHarness();
        when(
          () => harness.getDetail.call(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));

        final visited = <String>[];
        final router = GoRouter(
          initialLocation: '/pokemon/1',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) {
                visited.add('/');
                return const Scaffold(body: Text('list'));
              },
            ),
            GoRoute(
              path: '/pokemon/:id',
              builder: (_, state) => PokemonDetailScreen(
                id: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              getPokemonDetailProvider.overrideWithValue(harness.getDetail),
              getEvolutionChainProvider.overrideWithValue(harness.getChain),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Verify we're on the error screen, then tap Back.
        expect(
          find.text('You are offline and this Pokémon is not cached.'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Back'));
        await tester.pumpAndSettle();

        expect(visited, contains('/'));
        expect(find.text('list'), findsOneWidget);
      },
    );
  });

  group('PokemonDetailScreen — analytics (T-30b §12)', () {
    testWidgets(
      'switching tabs emits detail_tab_changed (never for the initial tab)',
      (tester) async {
        final harness = _makeHarness();
        final analytics = RecordingAnalytics();
        await _pumpScreen(tester, harness: harness, analytics: analytics);
        await tester.pumpAndSettle();

        // The first-shown About tab is not a change.
        expect(analytics.named('detail_tab_changed'), isEmpty);

        await tester.tap(find.text('Stats'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Evolution'));
        await tester.pumpAndSettle();
        // Tap back to About so all three DetailTab values are exercised.
        await tester.tap(find.text('About'));
        await tester.pumpAndSettle();

        final tabs = analytics
            .named('detail_tab_changed')
            .map((e) => e.parameters['tab'])
            .toList();
        expect(tabs, ['stats', 'evolution', 'about']);
      },
    );

    testWidgets(
      'offline failure emits error_shown TE-01 on the detail screen',
      (
        tester,
      ) async {
        final harness = _makeHarness();
        when(
          () => harness.getDetail.call(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        final analytics = RecordingAnalytics();

        await _pumpScreen(tester, harness: harness, analytics: analytics);
        await tester.pumpAndSettle();

        final shown = analytics.named('error_shown');
        expect(shown, hasLength(1));
        expect(shown.single.parameters, {
          'te_code': 'TE-01',
          'screen': 'pokemon_detail',
        });
      },
    );

    testWidgets(
      'generic failure emits error_shown TE-07 on the detail screen',
      (
        tester,
      ) async {
        final harness = _makeHarness();
        when(
          () => harness.getDetail.call(any()),
        ).thenAnswer((_) async => const Err(ServerFailure()));
        final analytics = RecordingAnalytics();

        await _pumpScreen(tester, harness: harness, analytics: analytics);
        await tester.pumpAndSettle();

        expect(analytics.named('error_shown').single.parameters, {
          'te_code': 'TE-07',
          'screen': 'pokemon_detail',
        });
      },
    );
  });
}
