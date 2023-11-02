import 'package:pokemon/models/named_resource_model.dart';

class PokemonTypeModel {
  final int? slot;
  final NamedResourceModel? type;

  PokemonTypeModel({
    this.slot,
    this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'slot': slot,
      'type': type != null ? type!.toJson() : null,
    };
  }

  factory PokemonTypeModel.fromJson(Map<String, dynamic> json) {
    return PokemonTypeModel(
      slot: json['slot'] != null ? json['slot'] as int : null,
      type: json['type'] != null
          ? NamedResourceModel.fromJson(json['type'])
          : null,
    );
  }
}
