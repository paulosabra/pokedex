import 'package:go_router/go_router.dart';
import 'package:pokedex/app/router/route_error_screen.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_detail_screen.dart';
import 'package:pokedex/features/pokemon/presentation/pages/pokemon_list_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// The application-scoped [GoRouter]. `keepAlive: true` so navigation history
/// (back stack, current location) survives provider rebuilds; disposing it on
/// rebuild would silently reset the user's place in the app.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PokemonListScreen(),
      ),
      GoRoute(
        path: '/pokemon/:id',
        builder: (context, state) {
          // C-1: under the T-31 SPA rewrite every path is served index.html,
          // so a malformed deep link (`/pokemon/abc`, or an id past the int64
          // range) is now reachable. `tryParse` turns the former crash into a
          // TE-03 page instead of throwing.
          final id = int.tryParse(state.pathParameters['id']!);
          if (id == null) return const RouteErrorScreen();
          return PokemonDetailScreen(id: id);
        },
      ),
    ],
    // Any unmatched path (e.g. a stale or hand-typed URL) also lands on the
    // TE-03 page rather than GoRouter's default error scaffold.
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
}
