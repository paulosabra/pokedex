import 'dart:js_interop';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pokemon/service/pokemon_service.dart';

import '../models/pokemon_model.dart';

part 'pokemon_event.dart';
part 'pokemon_state.dart';

class PokemonBloc extends Bloc<PokemonEvent, PokemonState> {
  PokemonBloc() : super(PokemonInitial()) {
    // on<PokemonEvent>(_onPokemonEvent);
    on<GetPokemonEvent>((event, emit) async {
      try {
        final response = await fetchPokemon(id: 30);
        PokemonModel pokemon = (response as PokemonModel);
        if (!pokemon.isNull) {
          emit(PokemonSuccess(data: pokemon));
        }
      } catch (error) {
        emit(PokemonError(error: error.toString()));
      }
    });
  }
}
