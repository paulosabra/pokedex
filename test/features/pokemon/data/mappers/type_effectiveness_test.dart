import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/dtos/type_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/type_effectiveness.dart';
import 'package:pokedex/features/pokemon/data/summary_encoding.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  DamageRelationsDto relations(String fixtureName) =>
      TypeDto.fromJson(fixtureJson(fixtureName)).damageRelations;

  late Map<PokemonTypeId, DamageRelationsDto> byType;

  setUp(() {
    byType = {
      PokemonTypeId.grass: relations('type_grass.json'),
      PokemonTypeId.poison: relations('type_poison.json'),
      PokemonTypeId.ground: relations('type_ground.json'),
      PokemonTypeId.electric: relations('type_electric.json'),
    };
  });

  group('pokemonTypeIdFromName', () {
    test('parses known type names', () {
      expect(pokemonTypeIdFromName('grass'), PokemonTypeId.grass);
      expect(pokemonTypeIdFromName('steel'), PokemonTypeId.steel);
    });

    test('returns null for an unknown type (TE-10)', () {
      expect(pokemonTypeIdFromName('stellar'), isNull);
    });
  });

  group('pokeApiTypeIds', () {
    test('covers all 18 types with PokeAPI ids', () {
      expect(pokeApiTypeIds.length, PokemonTypeId.values.length);
      expect(pokeApiTypeIds[PokemonTypeId.normal], 1);
      expect(pokeApiTypeIds[PokemonTypeId.grass], 12);
      expect(pokeApiTypeIds[PokemonTypeId.fairy], 18);
    });
  });

  group('computeTypeEffectiveness', () {
    test('single type (Grass) — 2x weaknesses and 0.5x resists', () {
      final effect = computeTypeEffectiveness(
        [PokemonTypeId.grass],
        byType,
      );

      expect(effect.typeDefenses[PokemonTypeId.fire], 2.0);
      expect(effect.typeDefenses[PokemonTypeId.ice], 2.0);
      expect(effect.typeDefenses[PokemonTypeId.water], 0.5);
      // Neutral matchups are omitted from the map.
      expect(effect.typeDefenses.containsKey(PokemonTypeId.normal), isFalse);
      expect(effect.weaknesses, contains(PokemonTypeId.fire));
      expect(effect.weaknesses, isNot(contains(PokemonTypeId.water)));
    });

    test('dual type (Grass/Poison, Bulbasaur) combines both types (RN-10)', () {
      final effect = computeTypeEffectiveness(
        [PokemonTypeId.grass, PokemonTypeId.poison],
        byType,
      );

      // Poison weak to psychic; grass neutral → 2x.
      expect(effect.typeDefenses[PokemonTypeId.psychic], 2.0);
      expect(effect.typeDefenses[PokemonTypeId.fire], 2.0);
      // Grass resists + poison resists grass → 0.25x.
      expect(effect.typeDefenses[PokemonTypeId.grass], 0.25);
      // Poison: grass weak (2) * poison resist (0.5) → neutral, omitted.
      expect(effect.typeDefenses.containsKey(PokemonTypeId.poison), isFalse);

      expect(
        effect.weaknesses,
        containsAll(<PokemonTypeId>[
          PokemonTypeId.fire,
          PokemonTypeId.psychic,
          PokemonTypeId.flying,
          PokemonTypeId.ice,
        ]),
      );
      expect(effect.weaknessMask, typeWeaknessMask(effect.weaknesses));
    });

    test('dual type yields a 4x weakness (Grass/Ground vs Ice)', () {
      final effect = computeTypeEffectiveness(
        [PokemonTypeId.grass, PokemonTypeId.ground],
        byType,
      );

      // Both grass and ground take 2x from ice → 4x.
      expect(effect.typeDefenses[PokemonTypeId.ice], 4.0);
      expect(effect.weaknesses, contains(PokemonTypeId.ice));
    });

    test('dual type yields a 0x immunity (Grass/Ground vs Electric)', () {
      final effect = computeTypeEffectiveness(
        [PokemonTypeId.grass, PokemonTypeId.ground],
        byType,
      );

      // Grass resists (0.5) * ground immune (0) → 0x, and never a weakness.
      expect(effect.typeDefenses[PokemonTypeId.electric], 0.0);
      expect(effect.weaknesses, isNot(contains(PokemonTypeId.electric)));
    });

    test('a missing defender relation degrades to neutral (TE-10)', () {
      // No relations provided → every attacker stays 1x, so no weaknesses.
      final effect = computeTypeEffectiveness(
        [PokemonTypeId.grass],
        const {},
      );

      expect(effect.typeDefenses, isEmpty);
      expect(effect.weaknesses, isEmpty);
      expect(effect.weaknessMask, 0);
    });
  });
}
