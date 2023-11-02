import 'package:pokemon/models/pokemon_dream_world_model.dart';

class PokemonOtherSpritesModel {
  final PokemonDreamWorldModel? dreamWorld;

  PokemonOtherSpritesModel({
    this.dreamWorld,
  });

  Map<String, dynamic> toJson() {
    return {
      'dream_world': dreamWorld != null ? dreamWorld!.toJson() : null,
    };
  }

  factory PokemonOtherSpritesModel.fromJson(Map<String, dynamic> json) {
    return PokemonOtherSpritesModel(
      dreamWorld: json['dream_world'] != null
          ? PokemonDreamWorldModel.fromJson(json['dream_world'])
          : null,
    );
  }
}
