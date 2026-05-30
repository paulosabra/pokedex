import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

part 'pokemon.freezed.dart';
part 'pokemon.g.dart';

/// A Pokémon list-card summary (RF-01). [types] is ordered primary-first
/// (RN-05); the primary type drives the card color (RN-04, UI).
///
/// An empty [types] list marks a **skeleton** entity — the row exists in
/// the global `PokemonIndex` cache but the per-id detail has not been
/// hydrated yet. Presentation reads `isSkeleton` to swap type badges for
/// shimmer placeholders; once the backfill writes the matching summary,
/// subsequent reads return the hydrated variant and the card upgrades in
/// place.
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

  /// Required by Freezed to expose [isSkeleton] as a derived getter.
  const Pokemon._();

  /// Deserializes a [Pokemon] from cache JSON.
  factory Pokemon.fromJson(Map<String, dynamic> json) =>
      _$PokemonFromJson(json);

  /// `true` when this entity was lifted from the index without a hydrated
  /// summary — see the class-level doc.
  bool get isSkeleton => types.isEmpty;
}
