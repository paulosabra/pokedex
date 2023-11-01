// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_stat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonStatModel _$PokemonStatModelFromJson(Map<String, dynamic> json) =>
    PokemonStatModel(
      baseStat: json['base_stat'] as int?,
      effort: json['effort'] as int?,
      stat: json['stat'] == null
          ? null
          : NamedResourceModel.fromJson(json['stat'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PokemonStatModelToJson(PokemonStatModel instance) =>
    <String, dynamic>{
      'base_stat': instance.baseStat,
      'effort': instance.effort,
      'stat': instance.stat,
    };
