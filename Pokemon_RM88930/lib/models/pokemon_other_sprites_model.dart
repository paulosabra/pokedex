// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:pokemon/models/pokemon_dream_world_model.dart';

class PokemonOtherSpritesModel {
  final PokemonDreamWorldModel? dreamWorld;

  PokemonOtherSpritesModel({
    this.dreamWorld,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'dream_world': dreamWorld?.toMap(),
    };
  }

  factory PokemonOtherSpritesModel.fromMap(Map<String, dynamic> map) {
    return PokemonOtherSpritesModel(
      dreamWorld: map['dream_world'] != null
          ? PokemonDreamWorldModel.fromMap(
              map['dream_world'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PokemonOtherSpritesModel.fromJson(String source) =>
      PokemonOtherSpritesModel.fromMap(
          json.decode(source) as Map<String, dynamic>);
}

/*
{
  "dream_world": {}
}
*/