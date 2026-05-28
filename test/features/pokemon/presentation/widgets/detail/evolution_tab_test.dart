import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/detail/evolution_tab.dart';

import '../../fixtures/eevee_evolution_chain.dart';

class _MockGetEvolutionChain extends Mock implements GetEvolutionChain {}

const _accent = Color(0xFF62B957);

Future<void> _pump(
  WidgetTester tester, {
  required _MockGetEvolutionChain getChain,
  required int id,
  GoRouter? router,
  Size size = const Size(414, 1200),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final app = ProviderScope(
    overrides: [getEvolutionChainProvider.overrideWithValue(getChain)],
    child: router != null
        ? MaterialApp.router(routerConfig: router)
        : MaterialApp(
            home: Scaffold(
              body: EvolutionTab(id: id, accent: _accent),
            ),
          ),
  );

  await tester.pumpWidget(app);
}

void main() {
  group('EvolutionTab', () {
    testWidgets('linear chain — Bulbasaur → Ivysaur → Venusaur', (
      tester,
    ) async {
      final getChain = _MockGetEvolutionChain();
      when(
        () => getChain.call(1),
      ).thenAnswer((_) async => Ok(bulbasaurEvolutionChain()));

      await _pump(tester, getChain: getChain, id: 1);
      await tester.pumpAndSettle();

      // The Figma's two-row layout shows the intermediate Pokémon twice —
      // once as the target of the first transition and once as the source
      // of the next. Linear chain renders: Bulbasaur→Ivysaur,
      // Ivysaur→Venusaur (matching frame `268:513`).
      expect(find.text('Bulbasaur'), findsOneWidget);
      expect(find.text('Ivysaur'), findsNWidgets(2));
      expect(find.text('Venusaur'), findsOneWidget);
      expect(find.text('(Level 16)'), findsOneWidget);
      expect(find.text('(Level 32)'), findsOneWidget);
    });

    testWidgets(
      'branching chain — Eevee renders all 8 children (resolved blocker 5)',
      (tester) async {
        final getChain = _MockGetEvolutionChain();
        when(
          () => getChain.call(133),
        ).thenAnswer((_) async => Ok(eeveeEvolutionChain()));

        await _pump(
          tester,
          getChain: getChain,
          id: 133,
          size: const Size(414, 2000),
        );
        await tester.pumpAndSettle();

        expect(find.text('Eevee'), findsOneWidget);
        expect(find.text('Vaporeon'), findsOneWidget);
        expect(find.text('Jolteon'), findsOneWidget);
        expect(find.text('Flareon'), findsOneWidget);
        expect(find.text('Espeon'), findsOneWidget);
        expect(find.text('Umbreon'), findsOneWidget);
        expect(find.text('Leafeon'), findsOneWidget);
        expect(find.text('Glaceon'), findsOneWidget);
        expect(find.text('Sylveon'), findsOneWidget);
      },
    );

    testWidgets(
      'no-evolution Pokémon shows the RN-13 informative message',
      (tester) async {
        final getChain = _MockGetEvolutionChain();
        when(
          () => getChain.call(128),
        ).thenAnswer((_) async => Ok(singleStageChain()));

        await _pump(tester, getChain: getChain, id: 128);
        await tester.pumpAndSettle();

        expect(find.text('This Pokémon does not evolve.'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsNothing);
      },
    );

    testWidgets('renders error message when the chain call fails', (
      tester,
    ) async {
      final getChain = _MockGetEvolutionChain();
      when(
        () => getChain.call(1),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      await _pump(tester, getChain: getChain, id: 1);
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load the evolution chain.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'tapping a stage navigates to /pokemon/<id> (resolved refine 3)',
      (tester) async {
        final getChain = _MockGetEvolutionChain();
        when(
          () => getChain.call(1),
        ).thenAnswer((_) async => Ok(bulbasaurEvolutionChain()));

        final visited = <String>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: EvolutionTab(id: 1, accent: _accent),
              ),
            ),
            GoRoute(
              path: '/pokemon/:id',
              builder: (_, state) {
                visited.add(state.pathParameters['id']!);
                return Scaffold(
                  body: Text('detail:${state.pathParameters['id']}'),
                );
              },
            ),
          ],
        );

        await _pump(tester, getChain: getChain, id: 1, router: router);
        await tester.pumpAndSettle();

        // Tap Venusaur (id 3) from the chain — its name is rendered on the
        // stage card.
        await tester.tap(find.text('Venusaur'));
        await tester.pumpAndSettle();

        expect(visited, contains('3'));
      },
    );

    testWidgets(
      'tapping a stage preserves the back-stack (resolved review-100 #5)',
      (tester) async {
        final getChain = _MockGetEvolutionChain();
        when(
          () => getChain.call(1),
        ).thenAnswer((_) async => Ok(bulbasaurEvolutionChain()));

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: EvolutionTab(id: 1, accent: _accent),
              ),
            ),
            GoRoute(
              path: '/pokemon/:id',
              builder: (_, state) => Scaffold(
                body: Text('detail:${state.pathParameters['id']}'),
              ),
            ),
          ],
        );

        await _pump(tester, getChain: getChain, id: 1, router: router);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Venusaur'));
        await tester.pump();

        // `canPop` is the precise distinction between push (true) and
        // go (false): push keeps the previous route on the stack so
        // system-back returns to the chain view.
        expect(router.canPop(), isTrue);
      },
    );
  });
}
