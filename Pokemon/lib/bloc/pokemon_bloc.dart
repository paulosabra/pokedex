import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pokemon/models/pokemon_model.dart';
import 'package:pokemon/service/pokemon_service.dart';

part 'pokemon_event.dart';
part 'pokemon_state.dart';

class PokemonBloc extends Bloc<PokemonEvent, PokemonState> {
  PokemonBloc() : super(PokemonInitial()) {
    on<GetPokemonEvent>(_onGetPokemonEvent);
  }

  void _onGetPokemonEvent(
    GetPokemonEvent event,
    Emitter emit,
  ) async {
    try {
      emit(PokemonLoading());

      final response = await fetchPokemon(event.id);

      emit(PokemonSuccess(data: response));
    } catch (error) {
      emit(PokemonError(error: error.toString()));
    }
  }
}
