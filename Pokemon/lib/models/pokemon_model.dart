import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pokemon/models/pokemon_sprites_model.dart';
import 'package:pokemon/models/pokemon_stat_model.dart';
import 'package:pokemon/models/pokemon_type_model.dart';

part 'pokemon_model.g.dart';

@JsonSerializable()
class PokemonModel extends Equatable {
  final int? id;
  final String? name;
  final int? height;
  final int? weight;
  final List<PokemonStatModel>? stats;
  final List<PokemonTypeModel>? types;
  final PokemonSpritesModel? sprites;

  const PokemonModel({
    this.id,
    this.name,
    this.height,
    this.weight,
    this.stats,
    this.types,
    this.sprites,
  });

  factory PokemonModel.fromJson(Map<String, dynamic> json) =>
      _$PokemonModelFromJson(json);

  Map<String, dynamic> toJson() => _$PokemonModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        height,
        weight,
        stats,
        types,
        sprites,
      ];
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