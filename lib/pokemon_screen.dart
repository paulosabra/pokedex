import 'package:flutter/material.dart';
import 'package:pokedex/pokemon_model.dart';
import 'package:pokedex/pokemon_service.dart';
import 'package:pokedex/resource_list_model.dart';

class PokemonScreen extends StatefulWidget {
  const PokemonScreen({super.key});

  @override
  State<PokemonScreen> createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> {
  late final Future<ResourceListModel?> futurePokemon;

  @override
  void initState() {
    super.initState();
    futurePokemon = fetchPokemonList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade800,
        title: const Text(
          'Pokédex',
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
                var resource = snapshot.data;
                return PokemonPage(pokemons: resource?.results);
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

class PokemonPage extends StatelessWidget {
  final List<PokemonModel>? pokemons;

  const PokemonPage({
    super.key,
    required this.pokemons,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: pokemons?.length ?? 0,
      itemBuilder: (context, index) {
        var item = pokemons?[index];
        return ListTile(
          title: Text(
            item?.name?.toUpperCase() ?? '-',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: Colors.white,
        );
      },
      separatorBuilder: (context, index) {
        return const SizedBox(height: 8);
      },
    );
  }
}
