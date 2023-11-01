import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pokemon/models/pokemon_dream_world_model.dart';

part 'pokemon_other_sprites_model.g.dart';

@JsonSerializable()
class PokemonOtherSpritesModel extends Equatable {
  @JsonKey(name: 'dream_world')
  final PokemonDreamWorldModel? dreamWorld;

  const PokemonOtherSpritesModel({
    this.dreamWorld,
  });

  factory PokemonOtherSpritesModel.fromJson(Map<String, dynamic> json) =>
      _$PokemonOtherSpritesModelFromJson(json);

  Map<String, dynamic> toJson() => _$PokemonOtherSpritesModelToJson(this);

  @override
  List<Object?> get props => [
        dreamWorld,
      ];
}

/*
{
  "dream_world": {}
}
*/