import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_list_response_dto.dart';

void main() {
  group('PokemonListResponseDto.fromJson', () {
    test('parses a page with pagination cursors', () {
      final dto = PokemonListResponseDto.fromJson(const {
        'count': 1302,
        'next': 'https://pokeapi.co/api/v2/pokemon?offset=20&limit=20',
        'previous': null,
        'results': [
          {'name': 'bulbasaur', 'url': 'https://pokeapi.co/api/v2/pokemon/1/'},
          {'name': 'ivysaur', 'url': 'https://pokeapi.co/api/v2/pokemon/2/'},
        ],
      });

      expect(dto.count, 1302);
      expect(dto.next, isNotNull);
      expect(dto.previous, isNull);
      expect(dto.results, hasLength(2));
      expect(dto.results.first.idFromUrl, 1);
    });

    test('defaults results to empty when the array is absent (TE-10)', () {
      final dto = PokemonListResponseDto.fromJson(const {'count': 0});

      expect(dto.results, isEmpty);
      expect(dto.next, isNull);
    });
  });
}
