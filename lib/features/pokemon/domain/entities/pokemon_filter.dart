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

/// Weight buckets for the weight filter, parallel to [HeightCategory] —
/// surfaced as a dedicated section on the Filters sheet per the Figma design
/// system (Components page, `Weight / *` symbols). Concrete hectogram
/// thresholds live in the data layer.
enum WeightCategory {
  /// Lighter Pokémon (under ~10 kg).
  light,

  /// Mid-weight Pokémon (~10–50 kg).
  normal,

  /// Heavier Pokémon (~50 kg and above).
  heavy,
}

/// Inclusive `[min, max]` National-Dex id window for the Number Range filter
/// section (Figma `Filters - Scrolled`).
typedef NumberRange = ({int min, int max});

/// The set of active list filters. Filters combine as an intersection and are
/// applied on top of the active search (RN-08).
@freezed
abstract class PokemonFilter with _$PokemonFilter {
  /// Creates a [PokemonFilter].
  const factory PokemonFilter({
    @Default(<PokemonTypeId>{}) Set<PokemonTypeId> types,
    @Default(<PokemonTypeId>{}) Set<PokemonTypeId> weaknesses,
    HeightCategory? height,
    WeightCategory? weight,
    int? generationId,
    NumberRange? numberRange,
  }) = _PokemonFilter;

  /// Required by Freezed to expose [isEmpty] as a derived getter.
  const PokemonFilter._();

  /// `true` when no filter axis is active. Lives on the entity so callers
  /// don't have to enumerate fields (and silently fall behind if a new axis
  /// is added later). The Home View uses this to disambiguate
  /// "filter excludes everything" from "no filter active, generation only".
  bool get isEmpty =>
      types.isEmpty &&
      weaknesses.isEmpty &&
      height == null &&
      weight == null &&
      generationId == null &&
      numberRange == null;
}
