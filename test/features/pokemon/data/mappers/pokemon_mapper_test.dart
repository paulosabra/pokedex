import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/pokemon_mapper.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  group('pokemonFromDto', () {
    test('maps a dual-type Pokémon (Bulbasaur), types ordered by slot', () {
      final pokemon = pokemonFromDto(
        PokemonDto.fromJson(fixtureJson('pokemon_bulbasaur.json')),
      );

      expect(pokemon.id, 1);
      expect(pokemon.name, 'bulbasaur');
      expect(pokemon.generationId, 1);
      expect(pokemon.types, [PokemonTypeId.grass, PokemonTypeId.poison]);
      expect(pokemon.imageUrl, contains('official-artwork/1.png'));
    });

    test('maps a single-type Pokémon (Pikachu)', () {
      final pokemon = pokemonFromDto(
        PokemonDto.fromJson(fixtureJson('pokemon_pikachu.json')),
      );

      expect(pokemon.types, [PokemonTypeId.electric]);
      expect(pokemon.generationId, 1);
    });

    test('falls back to an empty image url when sprites are absent', () {
      const dto = PokemonDto(id: 1, name: 'x', height: 1, weight: 1);
      expect(pokemonFromDto(dto).imageUrl, isEmpty);
    });

    test('drops unrecognized type names (TE-10)', () {
      const dto = PokemonDto(
        id: 1,
        name: 'x',
        height: 1,
        weight: 1,
        types: [
          PokemonTypeSlotDto(
            slot: 1,
            type: NamedApiResourceDto(url: '', name: 'mystery'),
          ),
          PokemonTypeSlotDto(
            slot: 2,
            type: NamedApiResourceDto(url: '', name: 'fire'),
          ),
        ],
      );

      expect(pokemonFromDto(dto).types, [PokemonTypeId.fire]);
    });
  });
}
