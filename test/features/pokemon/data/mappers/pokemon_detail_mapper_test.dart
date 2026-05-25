import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_detail_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/type_effectiveness.dart';
import 'package:pokedex/features/pokemon/domain/entities/ability.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  const effectiveness = TypeEffectiveness(
    weaknesses: [PokemonTypeId.fire, PokemonTypeId.psychic],
    typeDefenses: {PokemonTypeId.fire: 2.0, PokemonTypeId.water: 0.25},
    weaknessMask: 0,
  );

  PokemonDto pokemon(String name) => PokemonDto.fromJson(fixtureJson(name));
  PokemonSpeciesDto species(String name) =>
      PokemonSpeciesDto.fromJson(fixtureJson(name));
  List<LocationAreaEncounterDto> encounters(String name) => [
    for (final e in fixtureJsonArray(name))
      LocationAreaEncounterDto.fromJson(e as Map<String, dynamic>),
  ];

  group('pokemonDetailFromDtos (Bulbasaur)', () {
    test('maps scalar + species fields', () {
      final detail = pokemonDetailFromDtos(
        pokemon: pokemon('pokemon_bulbasaur.json'),
        species: species('species_bulbasaur.json'),
        effectiveness: effectiveness,
        encounters: const [],
      );

      expect(detail.summary.id, 1);
      expect(detail.heightMeters, 0.7);
      expect(detail.weightKg, 6.9);
      expect(detail.genus, 'Seed Pokémon');
      expect(detail.training.catchRate, 45);
      expect(detail.training.baseFriendship, 70);
      expect(detail.training.baseExp, 64);
      expect(detail.training.evYield, '1 Sp. Atk');
    });

    test('sanitizes the English flavor text (no control chars)', () {
      final detail = pokemonDetailFromDtos(
        pokemon: pokemon('pokemon_bulbasaur.json'),
        species: species('species_bulbasaur.json'),
        effectiveness: effectiveness,
        encounters: const [],
      );

      expect(detail.description, isNotEmpty);
      expect(detail.description, isNot(contains('\n')));
      expect(detail.description, isNot(contains('\f')));
      expect(detail.description, isNot(contains('  ')));
    });

    test('maps abilities, flagging the hidden one', () {
      final detail = pokemonDetailFromDtos(
        pokemon: pokemon('pokemon_bulbasaur.json'),
        species: species('species_bulbasaur.json'),
        effectiveness: effectiveness,
        encounters: const [],
      );

      expect(
        detail.abilities,
        contains(const Ability(name: 'overgrow', isHidden: false)),
      );
      expect(
        detail.abilities,
        contains(const Ability(name: 'chlorophyll', isHidden: true)),
      );
    });

    test('computes gendered percentages (RN-11)', () {
      final detail = pokemonDetailFromDtos(
        pokemon: pokemon('pokemon_bulbasaur.json'),
        species: species('species_bulbasaur.json'),
        effectiveness: effectiveness,
        encounters: const [],
      );

      // gender_rate 1 → 12.5% female, 87.5% male.
      expect(detail.breeding.gender.isGenderless, isFalse);
      expect(detail.breeding.gender.femalePercent, 12.5);
      expect(detail.breeding.gender.malePercent, 87.5);
      expect(detail.breeding.eggCycles, 20);
      expect(detail.breeding.eggGroups, isNotEmpty);
    });

    test('computes level-100 min/max base stats (RN-12)', () {
      final detail = pokemonDetailFromDtos(
        pokemon: pokemon('pokemon_bulbasaur.json'),
        species: species('species_bulbasaur.json'),
        effectiveness: effectiveness,
        encounters: const [],
      );

      // HP base 45: min 2*45+110=200, max 2*45+204=294.
      expect(detail.baseStats.hp.base, 45);
      expect(detail.baseStats.hp.min, 200);
      expect(detail.baseStats.hp.max, 294);
      // Attack base 49: min floor(103*0.9)=92, max floor(197*1.1)=216.
      expect(detail.baseStats.attack.base, 49);
      expect(detail.baseStats.attack.min, 92);
      expect(detail.baseStats.attack.max, 216);
      expect(detail.baseStats.total, 318);
    });

    test('carries the precomputed weaknesses and type defenses (RN-10)', () {
      final detail = pokemonDetailFromDtos(
        pokemon: pokemon('pokemon_bulbasaur.json'),
        species: species('species_bulbasaur.json'),
        effectiveness: effectiveness,
        encounters: const [],
      );

      expect(detail.weaknesses, effectiveness.weaknesses);
      expect(detail.typeDefenses, effectiveness.typeDefenses);
    });

    test('maps encounters to locations (RF-34)', () {
      final detail = pokemonDetailFromDtos(
        pokemon: pokemon('pokemon_bulbasaur.json'),
        species: species('species_bulbasaur.json'),
        effectiveness: effectiveness,
        encounters: encounters('encounters_bulbasaur.json'),
      );

      expect(detail.locations, isNotEmpty);
      expect(detail.locations.first.area, isNotEmpty);
      expect(detail.locations.first.versions, isNotEmpty);
    });
  });

  test('maps a genderless species to Genderless (Ditto, RN-11)', () {
    final detail = pokemonDetailFromDtos(
      pokemon: pokemon('pokemon_bulbasaur.json'),
      species: species('species_ditto.json'),
      effectiveness: effectiveness,
      encounters: const [],
    );

    expect(detail.breeding.gender.isGenderless, isTrue);
    expect(detail.breeding.gender.femalePercent, isNull);
  });

  test('degrades gracefully when species is missing (TE-10)', () {
    // The /pokemon data is still mapped; species-derived fields fall back.
    final detail = pokemonDetailFromDtos(
      pokemon: pokemon('pokemon_bulbasaur.json'),
      species: null,
      effectiveness: effectiveness,
      encounters: const [],
    );

    expect(detail.summary.id, 1);
    expect(detail.description, isEmpty);
    expect(detail.genus, isEmpty);
    expect(detail.training.catchRate, 0);
    expect(detail.training.baseFriendship, 0);
    expect(detail.training.growthRate, isEmpty);
    expect(detail.breeding.gender.isGenderless, isTrue);
    expect(detail.breeding.eggGroups, isEmpty);
    expect(detail.breeding.eggCycles, 0);
  });
}
