part of 'pokemon_bloc.dart';

sealed class PokemonState extends Equatable {
  const PokemonState();

  @override
  List<Object> get props => [];
}

final class PokemonInitial extends PokemonState {}

final class PokemonLoading extends PokemonState {}

final class PokemonSuccess extends PokemonState {
  final List<PokemonModel>? data;

  const PokemonSuccess({required this.data});
}

final class PokemonEmptyList extends PokemonState {}

final class PokemonError extends PokemonState {
  final String error;

  const PokemonError({required this.error});
}
