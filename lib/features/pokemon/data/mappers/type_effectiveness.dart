import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/summary_encoding.dart';

/// PokeAPI numeric ids for each type (used to fetch `/type/{id}`). These differ
/// from [PokemonTypeId.index], which is the app's own persisted ordering.
const pokeApiTypeIds = <PokemonTypeId, int>{
  PokemonTypeId.normal: 1,
  PokemonTypeId.fighting: 2,
  PokemonTypeId.flying: 3,
  PokemonTypeId.poison: 4,
  PokemonTypeId.ground: 5,
  PokemonTypeId.rock: 6,
  PokemonTypeId.bug: 7,
  PokemonTypeId.ghost: 8,
  PokemonTypeId.steel: 9,
  PokemonTypeId.fire: 10,
  PokemonTypeId.water: 11,
  PokemonTypeId.grass: 12,
  PokemonTypeId.electric: 13,
  PokemonTypeId.psychic: 14,
  PokemonTypeId.ice: 15,
  PokemonTypeId.dragon: 16,
  PokemonTypeId.dark: 17,
  PokemonTypeId.fairy: 18,
};

final Map<String, PokemonTypeId> _byName = {
  for (final type in PokemonTypeId.values) type.name: type,
};

/// Parses a PokéAPI type name (e.g. `grass`) into a [PokemonTypeId], or null
/// for an unrecognized type (e.g. `stellar`/`unknown`) — tolerant per TE-10.
PokemonTypeId? pokemonTypeIdFromName(String name) => _byName[name];

/// The defensive effectiveness of a Pokémon's type combination (RN-10).
class TypeEffectiveness {
  /// Creates a [TypeEffectiveness].
  const TypeEffectiveness({
    required this.weaknesses,
    required this.typeDefenses,
    required this.weaknessMask,
  });

  /// Attacking types dealing ≥2× damage (RF-31).
  final List<PokemonTypeId> weaknesses;

  /// Each attacking type's damage multiplier, excluding neutral 1× (RF-39).
  final Map<PokemonTypeId, double> typeDefenses;

  /// The 18-bit weakness mask for the SQL weakness filter (RF-15).
  final int weaknessMask;
}

/// Computes how each of the 18 attacking types fares against a Pokémon whose
/// own types are [defenderTypes], given each defender type's [relationsByType].
///
/// For every attacker the multiplier is the product, over the defender's types,
/// of 2 (double_damage_from), 0.5 (half_damage_from), 0 (no_damage_from), or 1.
/// A missing relation is treated as neutral (1×) so partial data degrades
/// gracefully (TE-10).
TypeEffectiveness computeTypeEffectiveness(
  List<PokemonTypeId> defenderTypes,
  Map<PokemonTypeId, DamageRelationsDto> relationsByType,
) {
  final defenses = <PokemonTypeId, double>{};
  for (final attacker in PokemonTypeId.values) {
    var multiplier = 1.0;
    for (final defender in defenderTypes) {
      final relations = relationsByType[defender];
      if (relations == null) continue;
      multiplier *= _factor(attacker, relations);
    }
    if (multiplier != 1.0) defenses[attacker] = multiplier;
  }

  final weaknesses = [
    for (final entry in defenses.entries)
      if (entry.value >= 2) entry.key,
  ];

  return TypeEffectiveness(
    weaknesses: weaknesses,
    typeDefenses: defenses,
    weaknessMask: typeWeaknessMask(weaknesses),
  );
}

double _factor(PokemonTypeId attacker, DamageRelationsDto relations) {
  bool contains(List<NamedApiResourceDto> resources) =>
      resources.any((r) => r.name == attacker.name);
  if (contains(relations.noDamageFrom)) return 0;
  if (contains(relations.doubleDamageFrom)) return 2;
  if (contains(relations.halfDamageFrom)) return 0.5;
  return 1;
}
