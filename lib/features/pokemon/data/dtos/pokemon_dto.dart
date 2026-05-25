import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';

part 'pokemon_dto.freezed.dart';
part 'pokemon_dto.g.dart';

/// Response of `GET /pokemon/{id}` — a single Pokémon's core data.
@freezed
abstract class PokemonDto with _$PokemonDto {
  /// Creates a [PokemonDto].
  const factory PokemonDto({
    required int id,
    required String name,
    required int height,
    required int weight,
    int? baseExperience,
    PokemonSpritesDto? sprites,
    @Default(<PokemonTypeSlotDto>[]) List<PokemonTypeSlotDto> types,
    @Default(<PokemonStatDto>[]) List<PokemonStatDto> stats,
    @Default(<PokemonAbilityDto>[]) List<PokemonAbilityDto> abilities,
  }) = _PokemonDto;

  /// Deserializes a [PokemonDto] from PokéAPI JSON.
  factory PokemonDto.fromJson(Map<String, dynamic> json) =>
      _$PokemonDtoFromJson(json);
}

/// One entry of a Pokémon's `types` array: a [slot] and its [type] resource.
@freezed
abstract class PokemonTypeSlotDto with _$PokemonTypeSlotDto {
  /// Creates a [PokemonTypeSlotDto].
  const factory PokemonTypeSlotDto({
    required int slot,
    required NamedApiResourceDto type,
  }) = _PokemonTypeSlotDto;

  /// Deserializes a [PokemonTypeSlotDto] from PokéAPI JSON.
  factory PokemonTypeSlotDto.fromJson(Map<String, dynamic> json) =>
      _$PokemonTypeSlotDtoFromJson(json);
}

/// One entry of a Pokémon's `stats` array: a base value and its [stat].
@freezed
abstract class PokemonStatDto with _$PokemonStatDto {
  /// Creates a [PokemonStatDto].
  const factory PokemonStatDto({
    required int baseStat,
    required int effort,
    required NamedApiResourceDto stat,
  }) = _PokemonStatDto;

  /// Deserializes a [PokemonStatDto] from PokéAPI JSON.
  factory PokemonStatDto.fromJson(Map<String, dynamic> json) =>
      _$PokemonStatDtoFromJson(json);
}

/// One entry of a Pokémon's `abilities` array.
@freezed
abstract class PokemonAbilityDto with _$PokemonAbilityDto {
  /// Creates a [PokemonAbilityDto].
  const factory PokemonAbilityDto({
    required NamedApiResourceDto ability,
    required bool isHidden,
    required int slot,
  }) = _PokemonAbilityDto;

  /// Deserializes a [PokemonAbilityDto] from PokéAPI JSON.
  factory PokemonAbilityDto.fromJson(Map<String, dynamic> json) =>
      _$PokemonAbilityDtoFromJson(json);
}

/// A Pokémon's `sprites` object. Only the official artwork is consumed.
@freezed
abstract class PokemonSpritesDto with _$PokemonSpritesDto {
  /// Creates a [PokemonSpritesDto].
  const factory PokemonSpritesDto({
    OtherSpritesDto? other,
  }) = _PokemonSpritesDto;

  /// Deserializes a [PokemonSpritesDto] from PokéAPI JSON.
  factory PokemonSpritesDto.fromJson(Map<String, dynamic> json) =>
      _$PokemonSpritesDtoFromJson(json);
}

/// The `sprites.other` object, holding alternate sprite sets.
@freezed
abstract class OtherSpritesDto with _$OtherSpritesDto {
  /// Creates an [OtherSpritesDto].
  const factory OtherSpritesDto({
    @JsonKey(name: 'official-artwork') OfficialArtworkDto? officialArtwork,
  }) = _OtherSpritesDto;

  /// Deserializes an [OtherSpritesDto] from PokéAPI JSON.
  factory OtherSpritesDto.fromJson(Map<String, dynamic> json) =>
      _$OtherSpritesDtoFromJson(json);
}

/// The `official-artwork` sprite set; [frontDefault] is the primary image URL.
@freezed
abstract class OfficialArtworkDto with _$OfficialArtworkDto {
  /// Creates an [OfficialArtworkDto].
  const factory OfficialArtworkDto({
    String? frontDefault,
  }) = _OfficialArtworkDto;

  /// Deserializes an [OfficialArtworkDto] from PokéAPI JSON.
  factory OfficialArtworkDto.fromJson(Map<String, dynamic> json) =>
      _$OfficialArtworkDtoFromJson(json);
}
