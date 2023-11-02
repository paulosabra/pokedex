// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class PokemonDreamWorldModel {
  final String? frontDefault;
  final String? frontFemale;

  PokemonDreamWorldModel({
    this.frontDefault,
    this.frontFemale,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'front_default': frontDefault,
      'front_female': frontFemale,
    };
  }

  factory PokemonDreamWorldModel.fromMap(Map<String, dynamic> map) {
    return PokemonDreamWorldModel(
      frontDefault:
          map['front_default'] != null ? map['front_default'] as String : null,
      frontFemale:
          map['front_female'] != null ? map['front_default'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PokemonDreamWorldModel.fromJson(String source) =>
      PokemonDreamWorldModel.fromMap(
          json.decode(source) as Map<String, dynamic>);
}

/*
{
  "front_default": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/dream-world/1.svg",
  "front_female": null
}
*/