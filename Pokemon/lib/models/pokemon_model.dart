// ignore_for_file: public_member_api_docs, sort_constructors_first
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'height': height,
      'weight': weight,
      'stats': stats != null
          ? List<PokemonStatModel>.from(stats!.map((x) => x.toMap())).toList()
          : [],
      'types': types != null
          ? List<PokemonTypeModel>.from(types!.map((x) => x.toMap())).toList()
          : [],
      'sprites': sprites?.toMap(),
    };
  }

  factory PokemonModel.fromJson(Map<String, dynamic> map) {
    return PokemonModel(
      id: map['id'] != null ? map['id'] as int : null,
      name: map['name'] != null ? map['name'] as String : null,
      height: map['height'] != null ? map['height'] as int : null,
      weight: map['weight'] != null ? map['weight'] as int : null,
      stats: map['stats'] != null
          ? List<PokemonStatModel>.from((map['stats']!.map(
              (x) => PokemonStatModel.fromMap(x),
            )))
          : null,
      types: map['types'] != null
          ? List<PokemonTypeModel>.from((map['types']!.map(
              (x) => PokemonTypeModel.fromMap(x),
            )))
          : null,
      sprites: map['sprites'] != null
          ? PokemonSpritesModel.fromMap(map['sprites'] as Map<String, dynamic>)
          : null,
    );
  }
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