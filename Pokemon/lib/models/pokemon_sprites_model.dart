// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:pokemon/models/pokemon_other_sprites_model.dart';

class PokemonSpritesModel {
  final PokemonOtherSpritesModel? other;

  PokemonSpritesModel({
    this.other,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'other': other?.toMap(),
    };
  }

  factory PokemonSpritesModel.fromMap(Map<String, dynamic> map) {
    return PokemonSpritesModel(
      other: map['other'] != null
          ? PokemonOtherSpritesModel.fromMap(
              map['other'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PokemonSpritesModel.fromJson(String source) =>
      PokemonSpritesModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

/*
{
  "other": {}
}
*/