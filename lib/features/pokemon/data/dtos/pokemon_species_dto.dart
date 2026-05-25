import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';

part 'pokemon_species_dto.freezed.dart';
part 'pokemon_species_dto.g.dart';

/// Response of `GET /pokemon-species/{id}` — breeding, training, and flavor data.
@freezed
abstract class PokemonSpeciesDto with _$PokemonSpeciesDto {
  /// Creates a [PokemonSpeciesDto].
  const factory PokemonSpeciesDto({
    required int id,
    required String name,
    required int genderRate,
    required int captureRate,
    required int baseHappiness,
    required int hatchCounter,
    required NamedApiResourceDto growthRate,
    required NamedApiResourceDto generation,
    required NamedApiResourceDto evolutionChain,
    @Default(<NamedApiResourceDto>[]) List<NamedApiResourceDto> eggGroups,
    @Default(<FlavorTextEntryDto>[]) List<FlavorTextEntryDto> flavorTextEntries,
    @Default(<GenusDto>[]) List<GenusDto> genera,
  }) = _PokemonSpeciesDto;

  /// Deserializes a [PokemonSpeciesDto] from PokéAPI JSON.
  factory PokemonSpeciesDto.fromJson(Map<String, dynamic> json) =>
      _$PokemonSpeciesDtoFromJson(json);
}

/// One localized Pokédex flavor-text entry.
@freezed
abstract class FlavorTextEntryDto with _$FlavorTextEntryDto {
  /// Creates a [FlavorTextEntryDto].
  const factory FlavorTextEntryDto({
    required String flavorText,
    required NamedApiResourceDto language,
    required NamedApiResourceDto version,
  }) = _FlavorTextEntryDto;

  /// Deserializes a [FlavorTextEntryDto] from PokéAPI JSON.
  factory FlavorTextEntryDto.fromJson(Map<String, dynamic> json) =>
      _$FlavorTextEntryDtoFromJson(json);
}

/// One localized genus label (e.g. "Seed Pokémon").
@freezed
abstract class GenusDto with _$GenusDto {
  /// Creates a [GenusDto].
  const factory GenusDto({
    required String genus,
    required NamedApiResourceDto language,
  }) = _GenusDto;

  /// Deserializes a [GenusDto] from PokéAPI JSON.
  factory GenusDto.fromJson(Map<String, dynamic> json) =>
      _$GenusDtoFromJson(json);
}
