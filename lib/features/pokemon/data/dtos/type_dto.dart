import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';

part 'type_dto.freezed.dart';
part 'type_dto.g.dart';

/// Response of `GET /type/{id}` — a type and its damage relations. These 18
/// charts are the source of truth for the weakness/effectiveness math (RN-01).
@freezed
abstract class TypeDto with _$TypeDto {
  /// Creates a [TypeDto].
  const factory TypeDto({
    required int id,
    required String name,
    required DamageRelationsDto damageRelations,
  }) = _TypeDto;

  /// Deserializes a [TypeDto] from PokéAPI JSON.
  factory TypeDto.fromJson(Map<String, dynamic> json) =>
      _$TypeDtoFromJson(json);
}

/// The six directional damage-relation lists for a single type.
@freezed
abstract class DamageRelationsDto with _$DamageRelationsDto {
  /// Creates a [DamageRelationsDto].
  const factory DamageRelationsDto({
    @Default(<NamedApiResourceDto>[])
    List<NamedApiResourceDto> doubleDamageFrom,
    @Default(<NamedApiResourceDto>[]) List<NamedApiResourceDto> halfDamageFrom,
    @Default(<NamedApiResourceDto>[]) List<NamedApiResourceDto> noDamageFrom,
    @Default(<NamedApiResourceDto>[]) List<NamedApiResourceDto> doubleDamageTo,
    @Default(<NamedApiResourceDto>[]) List<NamedApiResourceDto> halfDamageTo,
    @Default(<NamedApiResourceDto>[]) List<NamedApiResourceDto> noDamageTo,
  }) = _DamageRelationsDto;

  /// Deserializes a [DamageRelationsDto] from PokéAPI JSON.
  factory DamageRelationsDto.fromJson(Map<String, dynamic> json) =>
      _$DamageRelationsDtoFromJson(json);
}
