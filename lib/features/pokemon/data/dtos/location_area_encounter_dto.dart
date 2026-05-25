import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';

part 'location_area_encounter_dto.freezed.dart';
part 'location_area_encounter_dto.g.dart';

/// One element of the `GET /pokemon/{id}/encounters` top-level JSON array: a
/// location area and the per-game-version encounter details for it (RF-34).
@freezed
abstract class LocationAreaEncounterDto with _$LocationAreaEncounterDto {
  /// Creates a [LocationAreaEncounterDto].
  const factory LocationAreaEncounterDto({
    required NamedApiResourceDto locationArea,
    @Default(<VersionEncounterDetailDto>[])
    List<VersionEncounterDetailDto> versionDetails,
  }) = _LocationAreaEncounterDto;

  /// Deserializes a [LocationAreaEncounterDto] from PokéAPI JSON.
  factory LocationAreaEncounterDto.fromJson(Map<String, dynamic> json) =>
      _$LocationAreaEncounterDtoFromJson(json);
}

/// Encounter details for one game version at a location area.
@freezed
abstract class VersionEncounterDetailDto with _$VersionEncounterDetailDto {
  /// Creates a [VersionEncounterDetailDto].
  const factory VersionEncounterDetailDto({
    required NamedApiResourceDto version,
    required int maxChance,
    @Default(<EncounterDetailDto>[]) List<EncounterDetailDto> encounterDetails,
  }) = _VersionEncounterDetailDto;

  /// Deserializes a [VersionEncounterDetailDto] from PokéAPI JSON.
  factory VersionEncounterDetailDto.fromJson(Map<String, dynamic> json) =>
      _$VersionEncounterDetailDtoFromJson(json);
}

/// A single encounter: level range, chance, and the method used.
@freezed
abstract class EncounterDetailDto with _$EncounterDetailDto {
  /// Creates an [EncounterDetailDto].
  const factory EncounterDetailDto({
    required int chance,
    required int minLevel,
    required int maxLevel,
    required NamedApiResourceDto method,
  }) = _EncounterDetailDto;

  /// Deserializes an [EncounterDetailDto] from PokéAPI JSON.
  factory EncounterDetailDto.fromJson(Map<String, dynamic> json) =>
      _$EncounterDetailDtoFromJson(json);
}
