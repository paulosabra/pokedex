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

  Map<String, dynamic> toJson() {
    return {
      'baseStat': baseStat,
      'effort': effort,
      'stat': stat != null ? stat!.toJson() : null,
    };
  }

  factory PokemonStatModel.fromJson(Map<String, dynamic> json) {
    return PokemonStatModel(
      baseStat: json['baseStat'] != null ? json['baseStat'] as int : null,
      effort: json['effort'] != null ? json['effort'] as int : null,
      stat: json['stat'] != null
          ? NamedResourceModel.fromJson(json['stat'])
          : null,
    );
  }
}
