import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';

part 'evolution_chain_dto.freezed.dart';
part 'evolution_chain_dto.g.dart';

/// Response of `GET /evolution-chain/{id}` — the recursive evolution tree.
@freezed
abstract class EvolutionChainDto with _$EvolutionChainDto {
  /// Creates an [EvolutionChainDto].
  const factory EvolutionChainDto({
    required int id,
    required ChainLinkDto chain,
  }) = _EvolutionChainDto;

  /// Deserializes an [EvolutionChainDto] from PokéAPI JSON.
  factory EvolutionChainDto.fromJson(Map<String, dynamic> json) =>
      _$EvolutionChainDtoFromJson(json);
}

/// One node of the evolution tree. [evolvesTo] makes the structure recursive
/// (a node may branch into several, e.g. Eevee).
@freezed
abstract class ChainLinkDto with _$ChainLinkDto {
  /// Creates a [ChainLinkDto].
  const factory ChainLinkDto({
    required NamedApiResourceDto species,
    @Default(false) bool isBaby,
    @Default(<EvolutionDetailDto>[]) List<EvolutionDetailDto> evolutionDetails,
    @Default(<ChainLinkDto>[]) List<ChainLinkDto> evolvesTo,
  }) = _ChainLinkDto;

  /// Deserializes a [ChainLinkDto] from PokéAPI JSON.
  factory ChainLinkDto.fromJson(Map<String, dynamic> json) =>
      _$ChainLinkDtoFromJson(json);
}

/// The conditions under which one stage evolves into the next. Every trigger
/// detail is nullable — only the relevant ones are populated per species
/// (TE-10).
@freezed
abstract class EvolutionDetailDto with _$EvolutionDetailDto {
  /// Creates an [EvolutionDetailDto].
  const factory EvolutionDetailDto({
    required NamedApiResourceDto trigger,
    int? minLevel,
    NamedApiResourceDto? item,
    NamedApiResourceDto? heldItem,
    int? minHappiness,
    String? timeOfDay,
    NamedApiResourceDto? location,
    NamedApiResourceDto? knownMove,
    int? gender,
  }) = _EvolutionDetailDto;

  /// Deserializes an [EvolutionDetailDto] from PokéAPI JSON.
  factory EvolutionDetailDto.fromJson(Map<String, dynamic> json) =>
      _$EvolutionDetailDtoFromJson(json);
}
