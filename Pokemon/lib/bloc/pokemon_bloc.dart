import 'dart:js_interop';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/pokemon_model.dart';
import '../service/pokemon_service.dart';

part 'pokemon_event.dart';
part 'pokemon_state.dart';

class PokemonBloc extends Bloc<PokemonEvent, PokemonState> {
  PokemonBloc() : super(PokemonInitial()) {
    on<GetPokemonListEvent>((event, emit) async {
      try {
        emit(PokemonLoading());
        final response = await fetchPokemonList(id: 99);
        PokemonModel pokemonModel = response as PokemonModel;
        if (!pokemonModel.isNull) {
          emit(PokemonSuccess(data: pokemonModel));
        }
      } catch (error) {
        emit(PokemonError(error: error.toString()));
      }
    });
  }

  void _onPokemonEvent(
    PokemonEvent event,
    Emitter emit,
  ) async {}
}
