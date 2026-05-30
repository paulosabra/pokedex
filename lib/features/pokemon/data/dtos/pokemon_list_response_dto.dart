import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';

part 'pokemon_list_response_dto.freezed.dart';
part 'pokemon_list_response_dto.g.dart';

/// Response of `GET /pokemon?limit&offset` — a paginated index of resources.
@freezed
abstract class PokemonListResponseDto with _$PokemonListResponseDto {
  /// Creates a [PokemonListResponseDto].
  const factory PokemonListResponseDto({
    required int count,
    String? next,
    String? previous,
    @Default(<NamedApiResourceDto>[]) List<NamedApiResourceDto> results,
  }) = _PokemonListResponseDto;

  /// Deserializes a [PokemonListResponseDto] from PokéAPI JSON.
  factory PokemonListResponseDto.fromJson(Map<String, dynamic> json) =>
      _$PokemonListResponseDtoFromJson(json);
}
