import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pokemon/models/pokemon_other_sprites_model.dart';

part 'pokemon_sprites_model.g.dart';

@JsonSerializable()
class PokemonSpritesModel extends Equatable {
  final PokemonOtherSpritesModel? other;

  const PokemonSpritesModel({
    this.other,
  });

  factory PokemonSpritesModel.fromJson(Map<String, dynamic> json) =>
      _$PokemonSpritesModelFromJson(json);

  Map<String, dynamic> toJson() => _$PokemonSpritesModelToJson(this);

  @override
  List<Object?> get props => [
        other,
      ];
}

/*
{
  "other": {}
}
*/