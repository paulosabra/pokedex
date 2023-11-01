import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pokedex/bloc/pokemon_bloc.dart';
import 'package:pokedex/pokemon_model.dart';

class PokemonScreen extends StatefulWidget {
  const PokemonScreen({super.key});

  @override
  State<PokemonScreen> createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> {
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
          child: BlocProvider(
            create: (context) => PokemonBloc()..add(GetPokemonListEvent()),
            child: BlocBuilder<PokemonBloc, PokemonState>(
              builder: (context, state) {
                if (state is PokemonLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                }

                if (state is PokemonError) {
                  return Center(
                    child: Text(
                      state.error,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                if (state is PokemonEmptyList) {
                  return const Center(
                    child: Text(
                      'Lista Vazia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                if (state is PokemonSuccess) {
                  return PokemonPage(pokemons: state.data);
                }

                return const SizedBox();
              },
            ),
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
