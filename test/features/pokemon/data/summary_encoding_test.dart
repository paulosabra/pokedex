import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/data/summary_encoding.dart';

void main() {
  group('normalizeName', () {
    test('lowercases the input', () {
      expect(normalizeName('Bulbasaur'), 'bulbasaur');
      expect(normalizeName('PIKACHU'), 'pikachu');
    });

    test('strips common Latin diacritics (RN-07)', () {
      expect(normalizeName('Flabébé'), 'flabebe');
      expect(normalizeName('Pokémon'), 'pokemon');
      expect(normalizeName('NIDORÁN'), 'nidoran');
    });

    test('leaves unmapped characters untouched', () {
      expect(normalizeName("Farfetch'd"), "farfetch'd");
      expect(normalizeName('Ho-Oh'), 'ho-oh');
    });
  });

  group('typeWeaknessMask', () {
    test('an empty set encodes to 0', () {
      expect(typeWeaknessMask(const <PokemonTypeId>{}), 0);
    });

    test('a single type sets the bit at its index', () {
      // grass is index 0, poison index 1, fire index 2.
      expect(typeWeaknessMask({PokemonTypeId.grass}), 1);
      expect(typeWeaknessMask({PokemonTypeId.poison}), 2);
      expect(typeWeaknessMask({PokemonTypeId.fire}), 4);
    });

    test('multiple types OR their bits together', () {
      final mask = typeWeaknessMask({PokemonTypeId.grass, PokemonTypeId.fire});
      expect(mask, 1 | 4);
      // A non-member type does not intersect the mask.
      expect(mask & typeWeaknessMask({PokemonTypeId.water}), 0);
    });

    test('encodes the highest type index (steel, bit 17)', () {
      expect(typeWeaknessMask({PokemonTypeId.steel}), 1 << 17);
    });
  });
}
