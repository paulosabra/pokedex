// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_sprites_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonSpritesModel _$PokemonSpritesModelFromJson(Map<String, dynamic> json) =>
    PokemonSpritesModel(
      other: json['other'] == null
          ? null
          : PokemonOtherSpritesModel.fromJson(
              json['other'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PokemonSpritesModelToJson(
        PokemonSpritesModel instance) =>
    <String, dynamic>{
      'other': instance.other,
    };
