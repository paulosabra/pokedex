// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:pokemon/models/named_resource_model.dart';

class PokemonTypeModel {
  final int? slot;
  final NamedResourceModel? type;

  PokemonTypeModel({
    this.slot,
    this.type,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'slot': slot,
      'type': type?.toMap(),
    };
  }

  factory PokemonTypeModel.fromMap(Map<String, dynamic> map) {
    return PokemonTypeModel(
      slot: map['slot'] != null ? map['slot'] as int : null,
      type: map['type'] != null
          ? NamedResourceModel.fromMap(map['type'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PokemonTypeModel.fromJson(String source) =>
      PokemonTypeModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

/*
{
  "slot": 1,
  "type": {}
}
*/