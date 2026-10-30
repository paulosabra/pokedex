import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/models/entities/pokemon_type.dart';

void main() {
  group('PokemonType.fromApi (RN-10)', () {
    test('maps the 18 known API names', () {
      final known = PokemonType.values.where((t) => t != PokemonType.unknown);

      expect(known, hasLength(18));
      for (final type in known) {
        expect(PokemonType.fromApi(type.name), type);
      }
    });

    test('anything else is unknown', () {
      expect(PokemonType.fromApi('shadow'), PokemonType.unknown);
      expect(PokemonType.fromApi(''), PokemonType.unknown);
      expect(PokemonType.fromApi('Grass'), PokemonType.unknown);
    });
  });

  test('label is the capitalised name', () {
    expect(PokemonType.grass.label, 'Grass');
    expect(PokemonType.unknown.label, 'Unknown');
  });
}
