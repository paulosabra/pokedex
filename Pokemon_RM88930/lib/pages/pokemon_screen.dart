import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pokemon/bloc/pokemon_bloc.dart';
import 'package:pokemon/models/pokemon_model.dart';
import 'package:pokemon/pages/pokemon_page.dart';

class PokemonScreen extends StatefulWidget {
  const PokemonScreen({super.key});

  @override
  State<PokemonScreen> createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> {
  late final Future<PokemonModel?> futurePokemon;

  // @override
  // void initState() {
  //   super.initState();
  //   futurePokemon = fetchPokemon(id: 30);
  // }

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
            child: BlocProvider(
              create: (context) => PokemonBloc()..add(GetPokemonEvent()),
              child: BlocBuilder<PokemonBloc, PokemonState>(
                  builder: (context, state) {
                if (state is PokemonLoading) {
                  return const Center(
                      child: CircularProgressIndicator(
                    color: Colors.white,
                  ));
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

                if (state is PokemonSuccess) {
                  return PokemonPage(pokemon: state.data);
                }

                return const SizedBox();
              }),
            )),
      ),
    );
  }
}

// FutureBuilder(
//             future: futurePokemon,
//             builder: ((context, snapshot) {
//               if (snapshot.hasData) {
//                 var data = snapshot.data;
//                 return PokemonPage(pokemon: data);
//               }

//               if (snapshot.hasError) {
//                 return const Center(
//                   child: Text(
//                     'Erro na Requisição',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 32,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 );
//               }

//               return const Center(
//                 child: CircularProgressIndicator(
//                   color: Colors.white,
//                 ),
//               );
//             }),
//           ),