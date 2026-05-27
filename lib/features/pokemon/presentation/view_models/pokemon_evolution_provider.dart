import 'package:pokedex/core/error/result.dart';
import 'package:pokedex/features/pokemon/domain/entities/evolution_chain.dart';
import 'package:pokedex/features/pokemon/domain/usecases/get_evolution_chain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pokemon_evolution_provider.g.dart';

/// Lazy provider for a Pokémon's [EvolutionChain] (UC-07).
///
/// The Evolution tab is read-only — it consumes the chain and renders it.
/// There are no intents that would justify an `AsyncNotifier` ViewModel, so
/// the plan's conditional `PokemonEvolutionViewModel` is collapsed into a
/// thin `@riverpod` function provider (resolved refine 7: the chain loads
/// independently of the detail VM so the About/Stats tabs render first if
/// the evolution call is slower).
///
/// Family-keyed on [id] so distinct Pokémon hold independent results.
@riverpod
Future<EvolutionChain> pokemonEvolution(Ref ref, int id) async {
  final result = await ref.read(getEvolutionChainProvider).call(id);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}
