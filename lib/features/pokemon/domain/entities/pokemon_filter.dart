import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

part 'pokemon_filter.freezed.dart';

/// Height buckets for the height filter (RF-16). The PRD defines the categories
/// but not exact values; the concrete decimetre thresholds (the unit stored in
/// the cache) live in the data layer.
enum HeightCategory {
  /// Shorter Pokémon (under ~1 m).
  short,

  /// Mid-height Pokémon (~1–2 m).
  medium,

  /// Taller Pokémon (~2 m and above).
  tall,
}

/// The set of active list filters. Filters combine as an intersection and are
/// applied on top of the active search (RN-08).
@freezed
abstract class PokemonFilter with _$PokemonFilter {
  /// Creates a [PokemonFilter].
  const factory PokemonFilter({
    @Default(<PokemonTypeId>{}) Set<PokemonTypeId> types,
    @Default(<PokemonTypeId>{}) Set<PokemonTypeId> weaknesses,
    HeightCategory? height,
    int? generationId,
  }) = _PokemonFilter;
}
