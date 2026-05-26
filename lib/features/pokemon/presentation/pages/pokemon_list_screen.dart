import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder list screen wired by the domain epic. The UI epic (T-19+)
/// replaces this with the real list + search + filter implementation. A
/// single [ListTile] linking to `/pokemon/1` keeps the manual smoke test path
/// reachable without typing a URL.
class PokemonListScreen extends StatelessWidget {
  /// Creates the placeholder list screen.
  const PokemonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pokédex')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Pokémon #1'),
            onTap: () => context.go('/pokemon/1'),
          ),
        ],
      ),
    );
  }
}
