import 'package:flutter/material.dart';
import 'package:pokedex/app/theme/app_theme.dart';

/// Root application widget.
class PokedexApp extends StatelessWidget {
  /// Creates the root [PokedexApp].
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      theme: AppTheme.light,
      home: const Scaffold(),
    );
  }
}
