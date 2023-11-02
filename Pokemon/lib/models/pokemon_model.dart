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
    return {
      'id': id,
      'name': name,
      'height': height,
      'weight': weight,
      'stats': stats != null
          ? List<PokemonStatModel>.from(stats!.map((item) => item.toJson()))
          : [],
      'types': types != null
          ? List<PokemonTypeModel>.from(types!.map((item) => item.toJson()))
          : [],
      'sprites': sprites != null ? sprites!.toJson() : null,
    };
  }

  factory PokemonModel.fromJson(Map<String, dynamic> json) {
    return PokemonModel(
      id: json['id'] != null ? json['id'] as int : null,
      name: json['name'] != null ? json['name'] as String : null,
      height: json['height'] != null ? json['height'] as int : null,
      weight: json['weight'] != null ? json['weight'] as int : null,
      stats: json['stats'] != null
          ? List<PokemonStatModel>.from(
              json['stats']!.map((item) => PokemonStatModel.fromJson(item)),
            )
          : [],
      types: json['types'] != null
          ? List<PokemonTypeModel>.from(
              json['types']!.map((item) => PokemonTypeModel.fromJson(item)),
            )
          : [],
      sprites: json['sprites'] != null
          ? PokemonSpritesModel.fromJson(json['sprites'])
          : null,
    );
  }
}
