import 'package:pokemon/models/pokemon_other_sprites_model.dart';

class PokemonSpritesModel {
  final PokemonOtherSpritesModel? other;

  PokemonSpritesModel({
    this.other,
  });

  Map<String, dynamic> toJson() {
    return {
      'other': other != null ? other!.toJson() : null,
    };
  }

  factory PokemonSpritesModel.fromJson(Map<String, dynamic> json) {
    return PokemonSpritesModel(
      other: json['other'] != null
          ? PokemonOtherSpritesModel.fromJson(json['other'])
          : null,
    );
  }
}
