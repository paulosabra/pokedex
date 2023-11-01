import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'pokemon_event.dart';
part 'pokemon_state.dart';

class PokemonBloc extends Bloc<PokemonEvent, PokemonState> {
  PokemonBloc() : super(PokemonInitial()) {
    on<PokemonEvent>(_onPokemonEvent);
  }

  void _onPokemonEvent(
    PokemonEvent event,
    Emitter emit,
  ) async {}
}
