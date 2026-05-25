import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/dtos/evolution_chain_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/location_area_encounter_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/cache_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/evolution_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_detail_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_mapper.dart';
import 'package:pokedex/features/pokemon/data/mappers/type_effectiveness.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  final pokemon = pokemonFromDto(
    PokemonDto.fromJson(fixtureJson('pokemon_bulbasaur.json')),
  );

  group('summary cache', () {
    test('companion carries the derived SQL columns', () {
      final companion = summaryToCompanion(
        pokemon,
        heightDecimetres: 7,
        weaknessMask: 5,
        nowMs: 100,
      );

      expect(companion.name.value, 'bulbasaur');
      expect(companion.nameNormalized.value, 'bulbasaur');
      expect(companion.primaryTypeId.value, PokemonTypeId.grass.index);
      expect(companion.secondaryTypeId.value, PokemonTypeId.poison.index);
      expect(companion.generationId.value, 1);
      expect(companion.height.value, 7);
      expect(companion.weaknessMask.value, 5);
      expect(companion.updatedAt.value, 100);
    });

    test('row payload decodes back to the same entity', () {
      final companion = summaryToCompanion(
        pokemon,
        heightDecimetres: 7,
        weaknessMask: 5,
        nowMs: 100,
      );
      final row = PokemonSummaryRow(
        id: pokemon.id,
        name: pokemon.name,
        nameNormalized: 'bulbasaur',
        primaryTypeId: PokemonTypeId.grass.index,
        secondaryTypeId: PokemonTypeId.poison.index,
        generationId: 1,
        height: 7,
        weaknessMask: 5,
        payloadJson: companion.payloadJson.value,
        updatedAt: 100,
      );

      expect(pokemonFromRow(row), pokemon);
    });

    test('a single-type Pokémon has a null secondary type', () {
      final pikachu = pokemonFromDto(
        PokemonDto.fromJson(fixtureJson('pokemon_pikachu.json')),
      );

      final companion = summaryToCompanion(
        pikachu,
        heightDecimetres: 4,
        weaknessMask: 0,
        nowMs: 1,
      );

      expect(companion.primaryTypeId.value, PokemonTypeId.electric.index);
      expect(companion.secondaryTypeId.value, isNull);
    });
  });

  test('detail cache round-trips through payloadJson', () {
    final detail = pokemonDetailFromDtos(
      pokemon: PokemonDto.fromJson(fixtureJson('pokemon_bulbasaur.json')),
      species: PokemonSpeciesDto.fromJson(
        fixtureJson('species_bulbasaur.json'),
      ),
      effectiveness: const TypeEffectiveness(
        weaknesses: [PokemonTypeId.fire],
        typeDefenses: {PokemonTypeId.fire: 2.0, PokemonTypeId.water: 0.25},
        weaknessMask: 0,
      ),
      encounters: [
        for (final e in fixtureJsonArray('encounters_bulbasaur.json'))
          LocationAreaEncounterDto.fromJson(e as Map<String, dynamic>),
      ],
    );

    // Locations are populated, so the round-trip exercises LocationEntry JSON.
    expect(detail.locations, isNotEmpty);

    final companion = detailToCompanion(detail, nowMs: 1);
    final row = PokemonDetailRow(
      id: detail.summary.id,
      payloadJson: companion.payloadJson.value,
      updatedAt: 1,
    );

    expect(detailFromRow(row), detail);
  });

  test('evolution cache round-trips through payloadJson', () {
    final chain = evolutionChainFromDto(
      EvolutionChainDto.fromJson(fixtureJson('evolution_chain_eevee.json')),
    );

    final companion = evolutionToCompanion(67, chain, nowMs: 1);
    final row = EvolutionChainRow(
      chainId: 67,
      payloadJson: companion.payloadJson.value,
      updatedAt: 1,
    );

    expect(evolutionFromRow(row), chain);
  });

  test('type-relations cache round-trips through payloadJson', () {
    final relations = TypeDto.fromJson(
      fixtureJson('type_grass.json'),
    ).damageRelations;

    final companion = typeRelationToCompanion(
      PokemonTypeId.grass,
      relations,
      nowMs: 1,
    );
    expect(companion.typeId.value, PokemonTypeId.grass.index);

    final row = TypeRelationRow(
      typeId: PokemonTypeId.grass.index,
      payloadJson: companion.payloadJson.value,
      updatedAt: 1,
    );

    expect(damageRelationsFromRow(row), relations);
  });
}
