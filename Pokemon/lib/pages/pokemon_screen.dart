import 'package:flutter/material.dart';
import 'package:pokemon/models/pokemon_model.dart';
import 'package:pokemon/pages/pokemon_page.dart';
import 'package:pokemon/service/pokemon_service.dart';

class PokemonScreen extends StatefulWidget {
  const PokemonScreen({super.key});

  @override
  State<PokemonScreen> createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> {
  late final Future<PokemonModel?> futurePokemon;

  @override
  void initState() {
    super.initState();
    futurePokemon = fetchPokemon(id: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade800,
        title: const Text(
          'Pokémon',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: Colors.red.shade700,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder(
            future: futurePokemon,
            builder: ((context, snapshot) {
              if (snapshot.hasData) {
                var data = snapshot.data;
                return PokemonPage(pokemon: data);
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Erro na Requisição',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
