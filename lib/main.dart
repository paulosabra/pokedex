import 'package:flutter/material.dart';

void main() {
  runApp(const PokedexBootstrapApp());
}

class PokedexBootstrapApp extends StatelessWidget {
  const PokedexBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Pokédex',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Pokédex'))),
    );
  }
}
