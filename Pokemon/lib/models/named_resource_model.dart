import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'named_resource_model.g.dart';

@JsonSerializable()
class NamedResourceModel extends Equatable {
  final String? name;
  final String? url;

  const NamedResourceModel({
    this.name,
    this.url,
  });

  factory NamedResourceModel.fromJson(Map<String, dynamic> json) =>
      _$NamedResourceModelFromJson(json);

  Map<String, dynamic> toJson() => _$NamedResourceModelToJson(this);

  @override
  List<Object?> get props => [
        name,
        url,
      ];
}

/*
{
  "name": "poison",
  "url": "https://pokeapi.co/api/v2/type/4/"
}
*/
