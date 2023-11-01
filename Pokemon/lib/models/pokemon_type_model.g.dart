// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_type_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonTypeModel _$PokemonTypeModelFromJson(Map<String, dynamic> json) =>
    PokemonTypeModel(
      slot: json['slot'] as int?,
      type: json['type'] == null
          ? null
          : NamedResourceModel.fromJson(json['type'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PokemonTypeModelToJson(PokemonTypeModel instance) =>
    <String, dynamic>{
      'slot': instance.slot,
      'type': instance.type,
    };
