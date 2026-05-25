import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';

void main() {
  group('PokemonFilter', () {
    test('defaults to empty type/weakness sets and no height', () {
      // The DAO relies on these defaults to detect "no filter active".
      const filter = PokemonFilter();

      expect(filter.types, isEmpty);
      expect(filter.weaknesses, isEmpty);
      expect(filter.height, isNull);
    });
  });
}
