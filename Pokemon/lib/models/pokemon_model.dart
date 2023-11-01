import 'package:pokemon/models/pokemon_sprites_model.dart';
import 'package:pokemon/models/pokemon_stat_model.dart';
import 'package:pokemon/models/pokemon_type_model.dart';

class PokemonModel {
  final int? id;
  final String? name;
  final int? height;
  final int? weight;
  final List<PokemonStatModel>? stats;
  final List<PokemonTypeModel>? types;
  final PokemonSpritesModel? sprites;

  PokemonModel({
    this.id,
    this.name,
    this.height,
    this.weight,
    this.stats,
    this.types,
    this.sprites,
  });
}

/*
{
  "id": 1,
  "name": "bulbasaur",
  "height": 7,
  "weight": 69,
  "stats": [],
  "types": [],
  "sprites": {}
}
*/