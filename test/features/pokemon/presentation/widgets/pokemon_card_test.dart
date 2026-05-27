import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/core/ui/components/pokemon_card.dart' as core;
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/presentation/widgets/pokemon_card.dart';

const _bulbasaur = Pokemon(
  id: 1,
  name: 'bulbasaur',
  imageUrl: 'https://img/1.png',
  generationId: 1,
  types: [PokemonTypeId.grass, PokemonTypeId.poison],
);

const _charmander = Pokemon(
  id: 4,
  name: 'charmander',
  imageUrl: 'https://img/4.png',
  generationId: 1,
  types: [PokemonTypeId.fire],
);

Future<GoRouter> _pump(WidgetTester tester, Pokemon pokemon) async {
  String? lastVisited;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: PokemonCard(pokemon: pokemon),
        ),
      ),
      GoRoute(
        path: '/pokemon/:id',
        builder: (context, state) {
          lastVisited = state.uri.toString();
          return const Scaffold(body: Text('detail'));
        },
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  // Expose the captured route via a side-channel state field on the router's
  // GoRouterState — tests read it back below.
  addTearDown(router.dispose);
  _lastVisited[router] = () => lastVisited;
  return router;
}

final Map<GoRouter, String? Function()> _lastVisited = {};

void main() {
  group('PokemonCard adapter', () {
    testWidgets('forwards primitive params to core.PokemonCard', (
      tester,
    ) async {
      await _pump(tester, _bulbasaur);

      final core_ = tester.widget<core.PokemonCard>(
        find.byType(core.PokemonCard),
      );
      expect(core_.id, 1);
      expect(core_.name, 'bulbasaur');
      expect(core_.primaryType, PokemonTypeId.grass);
      expect(core_.secondaryType, PokemonTypeId.poison);
      expect(core_.imageUrl, 'https://img/1.png');
    });

    testWidgets('passes null secondaryType for single-type pokémon', (
      tester,
    ) async {
      await _pump(tester, _charmander);

      final core_ = tester.widget<core.PokemonCard>(
        find.byType(core.PokemonCard),
      );
      expect(core_.primaryType, PokemonTypeId.fire);
      expect(core_.secondaryType, isNull);
    });

    testWidgets('tap navigates to /pokemon/<id>', (tester) async {
      final router = await _pump(tester, _bulbasaur);

      await tester.tap(find.byType(core.PokemonCard));
      await tester.pumpAndSettle();

      expect(_lastVisited[router]!(), '/pokemon/1');
    });
  });
}
