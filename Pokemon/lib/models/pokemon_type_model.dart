import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pokemon/models/named_resource_model.dart';

part 'pokemon_type_model.g.dart';

@JsonSerializable()
class PokemonTypeModel extends Equatable {
  final int? slot;
  final NamedResourceModel? type;

  const PokemonTypeModel({
    this.slot,
    this.type,
  });

  factory PokemonTypeModel.fromJson(Map<String, dynamic> json) =>
      _$PokemonTypeModelFromJson(json);

  Map<String, dynamic> toJson() => _$PokemonTypeModelToJson(this);

  @override
  List<Object?> get props => [
        slot,
        type,
      ];
}

/*
{
  "slot": 1,
  "type": {}
}
*/