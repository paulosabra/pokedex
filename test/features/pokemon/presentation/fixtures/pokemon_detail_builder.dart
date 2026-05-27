import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/ability.dart';
import 'package:pokedex/features/pokemon/domain/entities/breeding.dart';
import 'package:pokedex/features/pokemon/domain/entities/location_entry.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/entities/stat_set.dart';
import 'package:pokedex/features/pokemon/domain/entities/training.dart';

/// Default Bulbasaur-shaped [PokemonDetail] for widget and screen tests.
///
/// Tests can `.copyWith(...)` the result to override individual fields
/// without rebuilding the full ten-field record every time.
PokemonDetail bulbasaurDetail() => const PokemonDetail(
  summary: Pokemon(
    id: 1,
    name: 'bulbasaur',
    imageUrl: 'https://img.test/1.png',
    generationId: 1,
    types: [PokemonTypeId.grass, PokemonTypeId.poison],
  ),
  description: 'Bulbasaur can be seen napping in bright sunlight.',
  genus: 'Seed Pokémon',
  heightMeters: 0.7,
  weightKg: 6.9,
  training: Training(
    evYield: '1 Special Attack',
    catchRate: 45,
    baseFriendship: 70,
    baseExp: 64,
    growthRate: 'Medium Slow',
  ),
  breeding: Breeding(
    gender: Gender(
      isGenderless: false,
      malePercent: 87.5,
      femalePercent: 12.5,
    ),
    eggCycles: 20,
    eggGroups: ['Monster', 'Grass'],
  ),
  baseStats: StatSet(
    hp: StatValue(base: 45, min: 200, max: 294),
    attack: StatValue(base: 49, min: 92, max: 216),
    defense: StatValue(base: 49, min: 92, max: 216),
    specialAttack: StatValue(base: 65, min: 121, max: 251),
    specialDefense: StatValue(base: 65, min: 121, max: 251),
    speed: StatValue(base: 45, min: 85, max: 207),
  ),
  abilities: [
    Ability(name: 'overgrow', isHidden: false),
    Ability(name: 'chlorophyll', isHidden: true),
  ],
  weaknesses: [
    PokemonTypeId.fire,
    PokemonTypeId.flying,
    PokemonTypeId.ice,
    PokemonTypeId.psychic,
  ],
  locations: [
    LocationEntry(area: 'Pallet Town', versions: ['Red', 'Blue']),
  ],
  typeDefenses: {
    PokemonTypeId.fire: 2.0,
    PokemonTypeId.water: 0.5,
    PokemonTypeId.poison: 0.0,
    PokemonTypeId.bug: 0.0,
  },
);
