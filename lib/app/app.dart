import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokedex/app/router/app_router.dart';
import 'package:pokedex/app/theme/app_theme.dart';

/// Root application widget. Wires the `GoRouter` from `routerProvider` into a
/// [MaterialApp.router] under the §10 theme.
class PokedexApp extends ConsumerWidget {
  /// Creates the root [PokedexApp].
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Pokédex',
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
