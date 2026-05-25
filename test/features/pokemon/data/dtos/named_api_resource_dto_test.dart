import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';

void main() {
  group('NamedApiResourceDto', () {
    test('parses a full named resource', () {
      final dto = NamedApiResourceDto.fromJson(const {
        'name': 'grass',
        'url': 'https://pokeapi.co/api/v2/type/12/',
      });

      expect(dto.name, 'grass');
      expect(dto.url, 'https://pokeapi.co/api/v2/type/12/');
    });

    test('name defaults to empty for a url-only resource', () {
      // The species `evolution_chain` field is `{ "url": ... }` with no name.
      final dto = NamedApiResourceDto.fromJson(const {
        'url': 'https://pokeapi.co/api/v2/evolution-chain/67/',
      });

      expect(dto.name, isEmpty);
      expect(dto.idFromUrl, 67);
    });

    group('idFromUrl', () {
      test('parses the trailing id from a standard resource url', () {
        const dto = NamedApiResourceDto(
          url: 'https://pokeapi.co/api/v2/pokemon/25/',
        );
        expect(dto.idFromUrl, 25);
      });

      test('handles a url without a trailing slash', () {
        const dto = NamedApiResourceDto(
          url: 'https://pokeapi.co/api/v2/type/4',
        );
        expect(dto.idFromUrl, 4);
      });

      test('returns null when there is no trailing integer', () {
        const dto = NamedApiResourceDto(url: 'https://example.com/foo/bar/');
        expect(dto.idFromUrl, isNull);
      });

      test('returns null for an empty url', () {
        const dto = NamedApiResourceDto(url: '');
        expect(dto.idFromUrl, isNull);
      });
    });
  });
}
