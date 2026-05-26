import 'package:flutter/material.dart';

/// Placeholder detail screen wired by the domain epic. The UI epic (T-19+)
/// replaces this with the real detail tabs implementation.
class PokemonDetailScreen extends StatelessWidget {
  /// Creates the placeholder detail screen for the Pokémon at [id].
  const PokemonDetailScreen({required this.id, super.key});

  /// The National Dex id parsed from the route's `:id` segment.
  final int id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#$id')),
      body: Center(child: Text('Pokémon #$id')),
    );
  }
}
