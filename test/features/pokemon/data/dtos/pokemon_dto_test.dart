import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_dto.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  group('PokemonDto.fromJson', () {
    test('parses a dual-type Pokémon (Bulbasaur #1) faithfully', () {
      final dto = PokemonDto.fromJson(fixtureJson('pokemon_bulbasaur.json'));

      expect(dto.id, 1);
      expect(dto.name, 'bulbasaur');
      expect(dto.height, 7);
      expect(dto.weight, 69);
      expect(dto.baseExperience, isNotNull);

      // Types carry their slot — PR3 sorts by slot to pick the primary type.
      expect(dto.types, hasLength(2));
      expect(dto.types.firstWhere((t) => t.slot == 1).type.name, 'grass');
      expect(dto.types.firstWhere((t) => t.slot == 2).type.name, 'poison');

      // Lock the `base_stat` snake_case mapping (PR3 Min/Max math depends on it).
      expect(dto.stats, hasLength(6));
      final hp = dto.stats.firstWhere((s) => s.stat.name == 'hp');
      expect(hp.baseStat, 45);
      expect(dto.abilities, isNotEmpty);

      // Hyphenated `official-artwork` key resolves via the explicit @JsonKey.
      expect(
        dto.sprites?.other?.officialArtwork?.frontDefault,
        contains('official-artwork/1.png'),
      );
    });

    test('parses a single-type Pokémon (Pikachu #25)', () {
      final dto = PokemonDto.fromJson(fixtureJson('pokemon_pikachu.json'));

      expect(dto.id, 25);
      expect(dto.name, 'pikachu');
      expect(dto.types, hasLength(1));
      expect(dto.types.single.type.name, 'electric');
    });

    test('tolerates a payload missing all optional fields (TE-10)', () {
      // Only the required scalars; no sprites, stats, types, or baseExperience.
      final dto = PokemonDto.fromJson(const {
        'id': 9999,
        'name': 'missingno',
        'height': 10,
        'weight': 100,
      });

      expect(dto.baseExperience, isNull);
      expect(dto.sprites, isNull);
      expect(dto.types, isEmpty);
      expect(dto.stats, isEmpty);
      expect(dto.abilities, isEmpty);
    });
  });
}
