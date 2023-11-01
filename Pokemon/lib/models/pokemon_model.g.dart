// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonModel _$PokemonModelFromJson(Map<String, dynamic> json) => PokemonModel(
      id: json['id'] as int?,
      name: json['name'] as String?,
      height: json['height'] as int?,
      weight: json['weight'] as int?,
      stats: (json['stats'] as List<dynamic>?)
          ?.map((e) => PokemonStatModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      types: (json['types'] as List<dynamic>?)
          ?.map((e) => PokemonTypeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sprites: json['sprites'] == null
          ? null
          : PokemonSpritesModel.fromJson(
              json['sprites'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PokemonModelToJson(PokemonModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'height': instance.height,
      'weight': instance.weight,
      'stats': instance.stats,
      'types': instance.types,
      'sprites': instance.sprites,
    };
