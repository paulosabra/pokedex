import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_species_dto.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  group('PokemonSpeciesDto.fromJson', () {
    test('parses species data (Bulbasaur) faithfully', () {
      final dto = fixtureJson('species_bulbasaur.json');
      final species = PokemonSpeciesDto.fromJson(dto);

      expect(species.id, 1);
      expect(species.name, 'bulbasaur');
      expect(species.genderRate, 1);
      expect(species.captureRate, greaterThan(0));
      expect(species.growthRate.name, isNotEmpty);
      expect(species.generation.name, 'generation-i');
      expect(species.eggGroups, isNotEmpty);
      expect(species.flavorTextEntries, isNotEmpty);
      expect(species.genera, isNotEmpty);

      // The url-only evolution_chain resource exposes its id via the helper.
      expect(species.evolutionChain.idFromUrl, isNotNull);
    });

    test('parses a genderless species (Ditto, gender_rate -1)', () {
      final species = PokemonSpeciesDto.fromJson(
        fixtureJson('species_ditto.json'),
      );

      expect(species.name, 'ditto');
      expect(species.genderRate, -1);
    });
  });
}
