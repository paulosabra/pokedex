import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/ability.dart';
import 'package:pokedex/features/pokemon/domain/entities/breeding.dart';
import 'package:pokedex/features/pokemon/domain/entities/location_entry.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/stat_set.dart';
import 'package:pokedex/features/pokemon/domain/entities/training.dart';

part 'pokemon_detail.freezed.dart';
part 'pokemon_detail.g.dart';

/// The full detail view of a Pokémon (RF-29…43). [weaknesses] are the attacking
/// types dealing ≥2× (RN-10); [typeDefenses] maps each attacking type to its
/// damage multiplier against this Pokémon (RF-39).
@freezed
abstract class PokemonDetail with _$PokemonDetail {
  /// Creates a [PokemonDetail].
  const factory PokemonDetail({
    required Pokemon summary,
    required String description,
    required String genus,
    required double heightMeters,
    required double weightKg,
    required Training training,
    required Breeding breeding,
    required StatSet baseStats,
    @Default(<Ability>[]) List<Ability> abilities,
    @Default(<PokemonTypeId>[]) List<PokemonTypeId> weaknesses,
    @Default(<LocationEntry>[]) List<LocationEntry> locations,
    @Default(<PokemonTypeId, double>{}) Map<PokemonTypeId, double> typeDefenses,
  }) = _PokemonDetail;

  /// Deserializes a [PokemonDetail] from cache JSON.
  factory PokemonDetail.fromJson(Map<String, dynamic> json) =>
      _$PokemonDetailFromJson(json);
}
