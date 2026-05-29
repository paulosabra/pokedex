import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/database/app_database.dart';
import 'package:pokedex/features/pokemon/data/dtos/named_api_resource_dto.dart';
import 'package:pokedex/features/pokemon/data/dtos/pokemon_list_response_dto.dart';
import 'package:pokedex/features/pokemon/data/mappers/index_mapper.dart';

void main() {
  group('indexFromResponse', () {
    test('maps each resource to a PokemonIndexCompanion', () {
      const response = PokemonListResponseDto(
        count: 3,
        results: [
          NamedApiResourceDto(
            url: 'https://pokeapi.co/api/v2/pokemon/1/',
            name: 'bulbasaur',
          ),
          NamedApiResourceDto(
            url: 'https://pokeapi.co/api/v2/pokemon/445/',
            name: 'garchomp',
          ),
          NamedApiResourceDto(
            url: 'https://pokeapi.co/api/v2/pokemon/1025/',
            name: 'pecharunt',
          ),
        ],
      );

      final rows = indexFromResponse(response, nowMs: 1234);

      expect(rows.map((r) => r.id), [
        const Value(1),
        const Value(445),
        const Value(1025),
      ]);
      expect(rows.map((r) => r.name), [
        const Value('bulbasaur'),
        const Value('garchomp'),
        const Value('pecharunt'),
      ]);
      expect(rows.map((r) => r.generationId), [
        const Value(1),
        const Value(4),
        const Value(9),
      ]);
      expect(rows.every((r) => r.indexedAt == const Value(1234)), isTrue);
    });

    test('skips rows whose URL has no parseable trailing id (TE-10)', () {
      // Alternate-form ids occasionally arrive with malformed URLs; the
      // mapper drops them rather than throwing so a single bad row doesn't
      // poison the snapshot.
      const response = PokemonListResponseDto(
        count: 2,
        results: [
          NamedApiResourceDto(url: '', name: 'broken'),
          NamedApiResourceDto(
            url: 'https://pokeapi.co/api/v2/pokemon/1/',
            name: 'bulbasaur',
          ),
        ],
      );

      final rows = indexFromResponse(response, nowMs: 0);

      expect(rows.map((r) => r.id), [const Value(1)]);
    });

    test('normalizes the name for accent/case-insensitive search', () {
      const response = PokemonListResponseDto(
        count: 1,
        results: [
          NamedApiResourceDto(
            url: 'https://pokeapi.co/api/v2/pokemon/669/',
            name: 'flabébé',
          ),
        ],
      );

      final rows = indexFromResponse(response, nowMs: 0);

      expect(rows.single.nameNormalized, const Value('flabebe'));
    });
  });

  group('skeletonFromIndexRow', () {
    test('lifts an index row to a Pokemon with empty types', () {
      const row = PokemonIndexRow(
        id: 445,
        name: 'garchomp',
        nameNormalized: 'garchomp',
        generationId: 4,
        indexedAt: 0,
      );

      final pokemon = skeletonFromIndexRow(row);

      expect(pokemon.id, 445);
      expect(pokemon.name, 'garchomp');
      expect(pokemon.generationId, 4);
      expect(pokemon.types, isEmpty);
      expect(pokemon.imageUrl, contains('/445.png'));
    });
  });
}
