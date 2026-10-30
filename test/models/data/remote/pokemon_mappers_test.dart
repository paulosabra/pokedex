import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pokedex/core/logging/loggers.dart';
import 'package:pokedex/models/data/remote/poke_api_client.dart';
import 'package:pokedex/models/data/remote/pokemon_mappers.dart';
import 'package:pokedex/models/entities/pokemon_stat.dart';
import 'package:pokedex/models/entities/pokemon_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/log_recorder.dart';

JsonMap _json(String name) => jsonDecode(fixture(name)) as JsonMap;

JsonMap _ref(String name) => {'name': name, 'url': 'https://pokeapi.co/x/'};

final _throwsParsingError = throwsA(
  anyOf(isA<FormatException>(), isA<TypeError>()),
);

void main() {
  group('PokemonMappers', () {
    group('index', () {
      test('RN-01 maps the 151 fixture entries with ids from the URL', () {
        final index = PokemonMappers.index(_json('index_151'));

        expect(index, hasLength(151));
        expect(index.map((p) => p.id), List.generate(151, (i) => i + 1));
        expect(index.first.name, 'bulbasaur');
        expect(index.last.name, 'mew');
      });

      test('RN-01 drops entries without an id or name with a WARNING', () {
        final logs = LogRecorder();
        final json = {
          'results': [
            {
              'name': 'bulbasaur',
              'url': 'https://pokeapi.co/api/v2/pokemon/1/',
            },
            {'name': 'broken', 'url': 'https://pokeapi.co/api/v2/pokemon/x/'},
            {'name': 'nourl'},
            {'url': 'https://pokeapi.co/api/v2/pokemon/3/'},
            {'name': 'ivysaur', 'url': 'https://pokeapi.co/api/v2/pokemon/2'},
          ],
        };

        final index = PokemonMappers.index(json);

        expect(index.map((p) => p.id), [1, 2]);
        logs.expectLog(
          Level.WARNING,
          LoggerNames.repository,
          'index entry dropped: no id or name {name=broken',
        );
        logs.expectLog(
          Level.WARNING,
          LoggerNames.repository,
          'index entry dropped: no id or name {name=nourl, url=null}',
        );
        logs.expectLog(
          Level.WARNING,
          LoggerNames.repository,
          'index entry dropped: no id or name {name=null, url=https://pokeapi.co/api/v2/pokemon/3/}',
        );
      });

      test('missing results throws', () {
        expect(() => PokemonMappers.index({}), _throwsParsingError);
      });
    });

    group('detail', () {
      test('maps bulbasaur', () {
        final detail = PokemonMappers.detail(_json('bulbasaur'));

        expect(detail.id, 1);
        expect(detail.name, 'bulbasaur');
        expect(detail.types, [PokemonType.grass, PokemonType.poison]);
        expect(detail.weightHg, 69);
        expect(detail.heightDm, 7);
        expect(detail.abilities, ['overgrow', 'chlorophyll']);
        expect(detail.stats, {
          StatKind.hp: 45,
          StatKind.attack: 49,
          StatKind.defense: 49,
          StatKind.specialAttack: 65,
          StatKind.specialDefense: 65,
          StatKind.speed: 45,
        });
        expect(detail.description, isNull);
      });

      test('RN-12 keeps the hidden ability (charmander)', () {
        final detail = PokemonMappers.detail(_json('charmander'));

        expect(detail.types, [PokemonType.fire]);
        expect(detail.abilities, ['blaze', 'solar-power']);
      });

      test('RN-12 keeps at most 2 abilities; mr-mime keeps its raw name', () {
        final detail = PokemonMappers.detail(_json('mr_mime'));

        expect(detail.name, 'mr-mime');
        expect(detail.summary.displayName, 'Mr. Mime');
        expect(detail.types, [PokemonType.psychic, PokemonType.fairy]);
        expect(detail.abilities, ['soundproof', 'filter']);
      });

      test('RF-18/RN-12 orders types and abilities by slot', () {
        final json = _json('bulbasaur')
          ..['types'] = [
            {'slot': 2, 'type': _ref('poison')},
            {'slot': 1, 'type': _ref('grass')},
          ]
          ..['abilities'] = [
            {'slot': 3, 'is_hidden': true, 'ability': _ref('chlorophyll')},
            {'slot': 1, 'is_hidden': false, 'ability': _ref('overgrow')},
          ];

        final detail = PokemonMappers.detail(json);

        expect(detail.types, [PokemonType.grass, PokemonType.poison]);
        expect(detail.abilities, ['overgrow', 'chlorophyll']);
      });

      test(
        'RN-10 unknown type → PokemonType.unknown; unknown stats ignored',
        () {
          final json = _json('bulbasaur')
            ..['types'] = [
              {'slot': 1, 'type': _ref('shadow')},
            ]
            ..['stats'] = [
              {'base_stat': 45, 'stat': _ref('hp')},
              {'base_stat': 10, 'stat': _ref('accuracy')},
            ];

          final detail = PokemonMappers.detail(json);

          expect(detail.types, [PokemonType.unknown]);
          expect(detail.stats, {StatKind.hp: 45});
        },
      );

      group('ERR-05 optional fields', () {
        for (final key in ['abilities', 'weight', 'height', 'stats']) {
          test('missing "$key" does not throw', () {
            final json = _json('bulbasaur')..remove(key);

            expect(() => PokemonMappers.detail(json), returnsNormally);
          });
        }

        test('degrade to empty list / null / absent key', () {
          final json = _json('bulbasaur')
            ..remove('abilities')
            ..remove('weight')
            ..remove('height')
            ..['stats'] = [
              {'base_stat': 45, 'stat': _ref('hp')},
            ];

          final detail = PokemonMappers.detail(json);

          expect(detail.abilities, isEmpty);
          expect(detail.weightHg, isNull);
          expect(detail.heightDm, isNull);
          expect(detail.stats.containsKey(StatKind.speed), isFalse);
          expect(detail.statOf(StatKind.speed), 0);
        });
      });

      group('ERR-05 required fields', () {
        for (final key in ['id', 'name', 'types']) {
          test('missing "$key" throws', () {
            final json = _json('bulbasaur')..remove(key);

            expect(() => PokemonMappers.detail(json), _throwsParsingError);
          });
        }

        test('empty "types" throws', () {
          final json = _json('bulbasaur')..['types'] = <Object?>[];

          expect(() => PokemonMappers.detail(json), _throwsParsingError);
        });

        test('wrongly typed "id" throws', () {
          final json = _json('bulbasaur')..['id'] = '1';

          expect(() => PokemonMappers.detail(json), _throwsParsingError);
        });
      });
    });

    group('description', () {
      test('RN-13 returns the first "en" entry, cleaned', () {
        expect(
          PokemonMappers.description(_json('bulbasaur_species')),
          'A strange seed was planted on its back at birth. '
          'The plant sprouts and grows with this POKéMON.',
        );
      });

      test('RN-13 skips entries in other languages', () {
        final json = {
          'flavor_text_entries': [
            {'flavor_text': 'Une graine', 'language': _ref('fr')},
            {'flavor_text': 'A seed\non its\fback', 'language': _ref('en')},
          ],
        };

        expect(PokemonMappers.description(json), 'A seed on its back');
      });

      test('RN-14 no "en" entry → null', () {
        final json = {
          'flavor_text_entries': [
            {'flavor_text': 'Une graine', 'language': _ref('fr')},
          ],
        };

        expect(PokemonMappers.description(json), isNull);
        expect(PokemonMappers.description({}), isNull);
      });
    });
  });
}
