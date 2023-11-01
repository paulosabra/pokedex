// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_other_sprites_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonOtherSpritesModel _$PokemonOtherSpritesModelFromJson(
        Map<String, dynamic> json) =>
    PokemonOtherSpritesModel(
      dreamWorld: json['dream_world'] == null
          ? null
          : PokemonDreamWorldModel.fromJson(
              json['dream_world'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PokemonOtherSpritesModelToJson(
        PokemonOtherSpritesModel instance) =>
    <String, dynamic>{
      'dream_world': instance.dreamWorld,
    };
