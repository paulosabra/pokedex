import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/pokemon/pokemon_type_id.dart';
import 'package:pokedex/features/pokemon/domain/entities/pokemon_filter.dart';

void main() {
  group('PokemonFilter', () {
    test('defaults to empty type/weakness sets, no height, no generation', () {
      // The DAO relies on these defaults to detect "no filter active".
      const filter = PokemonFilter();

      expect(filter.types, isEmpty);
      expect(filter.weaknesses, isEmpty);
      expect(filter.height, isNull);
      expect(filter.generationId, isNull);
    });

    test('copyWith preserves and overrides generationId independently', () {
      const initial = PokemonFilter(
        types: {PokemonTypeId.grass},
        generationId: 1,
      );

      final reGen = initial.copyWith(generationId: 2);
      expect(reGen.generationId, 2);
      expect(reGen.types, {PokemonTypeId.grass});
    });

    test('copyWith can clear generationId back to null', () {
      // The Home VM's `selectGeneration(null)` intent depends on this — Freezed
      // distinguishes "omitted" from "explicit null" via its sentinel.
      const initial = PokemonFilter(generationId: 1);

      expect(initial.copyWith(generationId: null).generationId, isNull);
    });

    group('isEmpty', () {
      test('default filter is empty', () {
        expect(const PokemonFilter().isEmpty, isTrue);
      });

      test('any type axis flips isEmpty to false', () {
        expect(
          const PokemonFilter(types: {PokemonTypeId.grass}).isEmpty,
          isFalse,
        );
      });

      test('any weakness axis flips isEmpty to false', () {
        expect(
          const PokemonFilter(weaknesses: {PokemonTypeId.fire}).isEmpty,
          isFalse,
        );
      });

      test('height axis flips isEmpty to false', () {
        expect(
          const PokemonFilter(height: HeightCategory.tall).isEmpty,
          isFalse,
        );
      });

      test('weight axis flips isEmpty to false', () {
        expect(
          const PokemonFilter(weight: WeightCategory.heavy).isEmpty,
          isFalse,
        );
      });

      test('generationId axis flips isEmpty to false', () {
        expect(const PokemonFilter(generationId: 1).isEmpty, isFalse);
      });
    });
  });
}
