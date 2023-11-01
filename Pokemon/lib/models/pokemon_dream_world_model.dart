import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pokemon_dream_world_model.g.dart';

@JsonSerializable()
class PokemonDreamWorldModel extends Equatable {
  @JsonKey(name: 'front_default')
  final String? frontDefault;
  @JsonKey(name: 'front_female')
  final String? frontFemale;

  const PokemonDreamWorldModel({
    this.frontDefault,
    this.frontFemale,
  });

  factory PokemonDreamWorldModel.fromJson(Map<String, dynamic> json) =>
      _$PokemonDreamWorldModelFromJson(json);

  Map<String, dynamic> toJson() => _$PokemonDreamWorldModelToJson(this);

  @override
  List<Object?> get props => [
        frontDefault,
        frontFemale,
      ];
}

/*
{
  "front_default": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/dream-world/1.svg",
  "front_female": null
}
*/