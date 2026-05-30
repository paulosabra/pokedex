import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/type_effectiveness.dart';
import 'package:pokedex/features/pokemon/domain/entities/ability.dart';
import 'package:pokedex/features/pokemon/domain/entities/breeding.dart';
import 'package:pokedex/features/pokemon/domain/entities/location_entry.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_detail.dart';
import 'package:pokedex/features/pokemon/domain/entities/stat_set.dart';
import 'package:pokedex/features/pokemon/domain/entities/training.dart';

const _statLabels = <String, String>{
  'hp': 'HP',
  'attack': 'Attack',
  'defense': 'Defense',
  'special-attack': 'Sp. Atk',
  'special-defense': 'Sp. Def',
  'speed': 'Speed',
};

final _whitespace = RegExp(r'\s+');
final _control = RegExp('[\f\n\r­]');

/// Composes a [PokemonDetail] from the Pokémon, species, computed type
/// [effectiveness], and encounter DTOs (RF-29…43). Degradable sections default
/// to empty when their source data is missing (TE-10).
PokemonDetail pokemonDetailFromDtos({
  required PokemonDto pokemon,
  required PokemonSpeciesDto? species,
  required TypeEffectiveness effectiveness,
  required List<LocationAreaEncounterDto> encounters,
}) {
  final baseStatByName = {
    for (final stat in pokemon.stats) stat.stat.name: stat.baseStat,
  };

  return PokemonDetail(
    summary: pokemonFromDto(pokemon),
    description: species == null ? '' : _englishFlavorText(species),
    genus: species == null ? '' : _englishGenus(species),
    heightMeters: pokemon.height / 10,
    weightKg: pokemon.weight / 10,
    training: Training(
      evYield: _evYield(pokemon),
      catchRate: species?.captureRate ?? 0,
      baseFriendship: species?.baseHappiness ?? 0,
      growthRate: species?.growthRate.name ?? '',
      baseExp: pokemon.baseExperience,
    ),
    breeding: Breeding(
      gender: _genderFromRate(species?.genderRate ?? -1),
      eggCycles: species?.hatchCounter ?? 0,
      eggGroups: species?.eggGroups.map((group) => group.name).toList() ?? [],
    ),
    baseStats: _statSet(baseStatByName),
    abilities: pokemon.abilities
        .map((a) => Ability(name: a.ability.name, isHidden: a.isHidden))
        .toList(),
    weaknesses: effectiveness.weaknesses,
    typeDefenses: effectiveness.typeDefenses,
    locations: _locations(encounters),
  );
}

/// Converts a PokéAPI gender rate (eighths, or -1) into a [Gender] (RN-11).
Gender _genderFromRate(int rate) {
  if (rate == -1) return const Gender(isGenderless: true);
  final female = rate / 8 * 100;
  return Gender(
    isGenderless: false,
    femalePercent: female,
    malePercent: 100 - female,
  );
}

StatSet _statSet(Map<String, int> baseByName) => StatSet(
  hp: _statValue(baseByName['hp'] ?? 0, isHp: true),
  attack: _statValue(baseByName['attack'] ?? 0),
  defense: _statValue(baseByName['defense'] ?? 0),
  specialAttack: _statValue(baseByName['special-attack'] ?? 0),
  specialDefense: _statValue(baseByName['special-defense'] ?? 0),
  speed: _statValue(baseByName['speed'] ?? 0),
);

/// Level-100 min/max for a base stat (RN-12). HP uses a distinct formula.
StatValue _statValue(int base, {bool isHp = false}) {
  if (isHp) {
    return StatValue(base: base, min: 2 * base + 110, max: 2 * base + 204);
  }
  return StatValue(
    base: base,
    min: ((2 * base + 5) * 0.9).floor(),
    max: ((2 * base + 99) * 1.1).floor(),
  );
}

String _evYield(PokemonDto pokemon) => pokemon.stats
    .where((stat) => stat.effort > 0)
    .map(
      (stat) =>
          '${stat.effort} ${_statLabels[stat.stat.name] ?? stat.stat.name}',
    )
    .join(', ');

List<LocationEntry> _locations(List<LocationAreaEncounterDto> encounters) => [
  for (final encounter in encounters)
    LocationEntry(
      area: encounter.locationArea.name,
      versions: {
        for (final detail in encounter.versionDetails) detail.version.name,
      }.toList(),
    ),
];

String _englishFlavorText(PokemonSpeciesDto species) {
  final english = species.flavorTextEntries.where(
    (entry) => entry.language.name == 'en',
  );
  return english.isEmpty ? '' : _sanitize(english.first.flavorText);
}

String _englishGenus(PokemonSpeciesDto species) {
  final english = species.genera.where((entry) => entry.language.name == 'en');
  return english.isEmpty ? '' : english.first.genus;
}

String _sanitize(String text) =>
    text.replaceAll(_control, ' ').replaceAll(_whitespace, ' ').trim();
