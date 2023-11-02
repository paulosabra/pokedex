// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:pokemon/models/named_resource_model.dart';

class PokemonStatModel {
  final int? baseStat;
  final int? effort;
  final NamedResourceModel? stat;

  PokemonStatModel({
    this.baseStat,
    this.effort,
    this.stat,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'base_stat': baseStat,
      'effort': effort,
      'stat': stat?.toMap(),
    };
  }

  factory PokemonStatModel.fromMap(Map<String, dynamic> map) {
    return PokemonStatModel(
      baseStat: map['base_stat'] != null ? map['base_stat'] as int : null,
      effort: map['effort'] != null ? map['effort'] as int : null,
      stat: map['stat'] != null
          ? NamedResourceModel.fromMap(map['stat'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PokemonStatModel.fromJson(String source) =>
      PokemonStatModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

/*
{
  "base_stat": 45,
  "effort": 0,
  "stat": {}
}
*/