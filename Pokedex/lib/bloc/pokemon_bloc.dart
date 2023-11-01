import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pokedex/pokemon_model.dart';
import 'package:pokedex/pokemon_service.dart';
import 'package:pokedex/resource_list_model.dart';

part 'pokemon_event.dart';
part 'pokemon_state.dart';

class PokemonBloc extends Bloc<PokemonEvent, PokemonState> {
  PokemonBloc() : super(PokemonInitial()) {
    on<GetPokemonListEvent>((event, emit) async {
      try {
        emit(PokemonLoading());

        final response = await fetchPokemonList();
        List<PokemonModel>? list = (response as ResourceListModel).results;
        if (list!.isNotEmpty) {
          emit(PokemonSuccess(data: list));
        } else {
          emit(PokemonEmptyList());
        }
      } catch (error) {
        emit(PokemonError(error: error.toString()));
      }
    });
  }
}
