import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';

void main() {
  group('PokemonTypeId', () {
    test('has all 18 types', () {
      expect(PokemonTypeId.values, hasLength(18));
    });

    test('preserves the persisted index order (cache contract)', () {
      // These indices are persisted in the SQLite cache (primary/secondary type
      // ids and the weakness bitmask). Reordering would corrupt existing rows,
      // so the order is pinned here as a guard.
      expect(PokemonTypeId.grass.index, 0);
      expect(PokemonTypeId.poison.index, 1);
      expect(PokemonTypeId.fire.index, 2);
      expect(PokemonTypeId.normal.index, 6);
      expect(PokemonTypeId.steel.index, 17);
    });
  });
}
