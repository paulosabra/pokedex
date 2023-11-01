import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pokemon/models/named_resource_model.dart';

part 'pokemon_stat_model.g.dart';

@JsonSerializable()
class PokemonStatModel extends Equatable {
  @JsonKey(name: 'base_stat')
  final int? baseStat;
  final int? effort;
  final NamedResourceModel? stat;

  const PokemonStatModel({
    this.baseStat,
    this.effort,
    this.stat,
  });

  factory PokemonStatModel.fromJson(Map<String, dynamic> json) =>
      _$PokemonStatModelFromJson(json);

  Map<String, dynamic> toJson() => _$PokemonStatModelToJson(this);

  @override
  List<Object?> get props => [
        baseStat,
        effort,
        stat,
      ];
}

/*
{
  "base_stat": 45,
  "effort": 0,
  "stat": {}
}
*/