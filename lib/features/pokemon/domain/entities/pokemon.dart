import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

part 'pokemon.freezed.dart';
part 'pokemon.g.dart';

/// A Pokémon list-card summary (RF-01). [types] is ordered primary-first
/// (RN-05); the primary type drives the card color (RN-04, UI).
@freezed
abstract class Pokemon with _$Pokemon {
  /// Creates a [Pokemon].
  const factory Pokemon({
    required int id,
    required String name,
    required String imageUrl,
    required int generationId,
    @Default(<PokemonTypeId>[]) List<PokemonTypeId> types,
  }) = _Pokemon;

  /// Deserializes a [Pokemon] from cache JSON.
  factory Pokemon.fromJson(Map<String, dynamic> json) =>
      _$PokemonFromJson(json);
}
