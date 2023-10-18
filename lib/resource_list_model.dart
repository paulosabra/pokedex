import 'package:pokedex/pokemon_model.dart';

class ResourceListModel {
  final int? count;
  final String? next;
  final String? previous;
  final List<PokemonModel>? results;

  ResourceListModel({
    this.count,
    this.next,
    this.previous,
    this.results,
  });
}
