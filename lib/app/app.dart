import 'package:flutter/material.dart';

/// Root application widget.
class PokedexApp extends StatelessWidget {
  /// Creates the root [PokedexApp].
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Pokédex', home: Scaffold());
  }
}
