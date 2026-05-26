import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pokedex/app/app.dart';
import 'package:pokedex/app/router/app_router.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_detail_screen.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';

GoRouter _routerAt(String location) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PokemonListScreen(),
    ),
    GoRoute(
      path: '/pokemon/:id',
      builder: (context, state) => PokemonDetailScreen(
        id: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
);

void main() {
  testWidgets('PokedexApp boots and composes a themed MaterialApp.router', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWith((ref) => _routerAt('/'))],
        child: const PokedexApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routerConfig, isNotNull);
    expect(app.theme, isNotNull);
    expect(app.theme!.scaffoldBackgroundColor, AppColors.backgroundWhite);
    expect(find.byType(PokemonListScreen), findsOneWidget);
  });

  testWidgets('deep-linking to /pokemon/25 renders the detail placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith((ref) => _routerAt('/pokemon/25')),
        ],
        child: const PokedexApp(),
      ),
    );
    await tester.pumpAndSettle();

    final detail = tester.widget<PokemonDetailScreen>(
      find.byType(PokemonDetailScreen),
    );
    expect(detail.id, 25);
  });
}
