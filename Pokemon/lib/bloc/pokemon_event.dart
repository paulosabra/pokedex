part of 'pokemon_bloc.dart';

sealed class PokemonEvent extends Equatable {
  const PokemonEvent();

  @override
  List<Object> get props => [];
}

class GetPokemonEvent extends PokemonEvent {
  final int id;

  const GetPokemonEvent(this.id);
}
