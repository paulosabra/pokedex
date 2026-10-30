import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:pokedex/core/errors/app_failure.dart';
import 'package:pokedex/core/errors/result.dart';
import 'package:pokedex/core/logging/loggers.dart';
import 'package:pokedex/models/data/remote/poke_api_client.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/log_recorder.dart';

http.Response _json(String body, [int status = 200]) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

PokeApiClient _client(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 10),
}) => PokeApiClient(httpClient: MockClient(handler), timeout: timeout);

Future<AppFailure> _failureOf(Future<Result<JsonMap>> call) async =>
    switch (await call) {
      Err(:final failure) => failure,
      Ok() => throw TestFailure('expected Err'),
    };

void main() {
  late LogRecorder logs;

  setUp(() => logs = LogRecorder());

  group('PokeApiClient', () {
    group('endpoints', () {
      late List<Uri> requested;
      late PokeApiClient client;

      setUp(() {
        requested = [];
        client = _client((request) async {
          requested.add(request.url);
          return _json('{}');
        });
      });

      test('fetchIndex → GET pokemon?limit=151&offset=0', () async {
        await client.fetchIndex();

        expect(requested, [
          Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=151&offset=0'),
        ]);
      });

      test('fetchPokemon(4) → GET pokemon/4', () async {
        await client.fetchPokemon(4);

        expect(requested, [Uri.parse('https://pokeapi.co/api/v2/pokemon/4')]);
      });

      test('fetchSpecies(4) → GET pokemon-species/4', () async {
        await client.fetchSpecies(4);

        expect(requested, [
          Uri.parse('https://pokeapi.co/api/v2/pokemon-species/4'),
        ]);
      });

      test('resolves paths against an injected baseUrl', () async {
        final custom = PokeApiClient(
          httpClient: MockClient((request) async {
            requested.add(request.url);
            return _json('{}');
          }),
          baseUrl: Uri.parse('http://localhost:8080/v2/'),
        );

        await custom.fetchPokemon(25);

        expect(requested, [Uri.parse('http://localhost:8080/v2/pokemon/25')]);
      });
    });

    group('PRD §10.2 status mapping', () {
      test('200 → Ok(JsonMap) with the decoded fixture', () async {
        final client = _client((_) async => _json(fixture('index_151')));

        final result = await client.fetchIndex();

        expect(result, isA<Ok<JsonMap>>());
        final json = (result as Ok<JsonMap>).value;
        expect(json['results'], hasLength(151));
      });

      test(
        'TS-12 200 with a body > 64 KB decodes via the isolate path',
        () async {
          final body = fixture('bulbasaur');
          expect(shouldDecodeInIsolate(utf8.encode(body).length), isTrue);
          final client = _client((_) async => _json(body));

          final result = await client.fetchPokemon(1);

          expect((result as Ok<JsonMap>).value['name'], 'bulbasaur');
        },
      );

      test('decodes UTF-8 even without a charset header', () async {
        final client = _client(
          (_) async =>
              http.Response.bytes(utf8.encode('{"genus":"Seed Pokémon"}'), 200),
        );

        final result = await client.fetchSpecies(1);

        expect((result as Ok<JsonMap>).value['genus'], 'Seed Pokémon');
      });

      test('404 → NotFoundFailure (WARNING)', () async {
        final client = _client((_) async => _json('Not Found', 404));

        final failure = await _failureOf(client.fetchPokemon(999));

        expect(failure, isA<NotFoundFailure>());
        logs.expectLog(
          Level.WARNING,
          LoggerNames.api,
          'NotFoundFailure on GET /pokemon/999 → 404',
        );
      });

      test('429 → RateLimitFailure (WARNING)', () async {
        final client = _client((_) async => _json('', 429));

        final failure = await _failureOf(client.fetchPokemon(4));

        expect(failure, isA<RateLimitFailure>());
        logs.expectLog(
          Level.WARNING,
          LoggerNames.api,
          'RateLimitFailure on GET /pokemon/4 → 429',
        );
      });

      for (final status in [500, 418]) {
        test('$status → ServerFailure($status) (SEVERE)', () async {
          final client = _client((_) async => _json('', status));

          final failure = await _failureOf(client.fetchPokemon(4));

          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).statusCode, status);
          logs.expectLog(
            Level.SEVERE,
            LoggerNames.api,
            'ServerFailure on GET /pokemon/4 → $status',
          );
        });
      }

      test('SocketException → NetworkFailure (WARNING)', () async {
        const error = SocketException('Failed host lookup');
        final client = _client((_) async => throw error);

        final failure = await _failureOf(client.fetchIndex());

        expect(failure, isA<NetworkFailure>());
        expect(failure.cause, same(error));
        logs.expectLog(
          Level.WARNING,
          LoggerNames.api,
          'NetworkFailure on GET /pokemon?limit=151&offset=0',
        );
      });

      test('ClientException → NetworkFailure (WARNING)', () async {
        final client = _client(
          (_) async => throw http.ClientException('Connection closed'),
        );

        final failure = await _failureOf(client.fetchPokemon(4));

        expect(failure, isA<NetworkFailure>());
        logs.expectLog(
          Level.WARNING,
          LoggerNames.api,
          'NetworkFailure on GET /pokemon/4',
        );
      });

      test('response slower than timeout → TimeoutFailure (WARNING)', () async {
        final client = _client(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 10),
        );

        final failure = await _failureOf(client.fetchPokemon(4));

        expect(failure, isA<TimeoutFailure>());
        logs.expectLog(
          Level.WARNING,
          LoggerNames.api,
          'TimeoutFailure on GET /pokemon/4',
        );
      });

      test('non-JSON body → ParsingFailure (SEVERE)', () async {
        final client = _client((_) async => _json('<html>oops</html>'));

        final failure = await _failureOf(client.fetchPokemon(4));

        expect(failure, isA<ParsingFailure>());
        expect(failure.cause, isA<FormatException>());
        logs.expectLog(
          Level.SEVERE,
          LoggerNames.api,
          'ParsingFailure on GET /pokemon/4 → 200 body="<html>oops</html>"',
        );
      });

      test('JSON that is not an object → ParsingFailure (SEVERE)', () async {
        final client = _client((_) async => _json('[1, 2]'));

        final failure = await _failureOf(client.fetchPokemon(4));

        expect(failure, isA<ParsingFailure>());
        logs.expectLog(
          Level.SEVERE,
          LoggerNames.api,
          'ParsingFailure on GET /pokemon/4 → 200 body="[1, 2]"',
        );
      });

      test('any other exception → UnexpectedFailure (SEVERE)', () async {
        final error = StateError('boom');
        final client = _client((_) async => throw error);

        final failure = await _failureOf(client.fetchPokemon(4));

        expect(failure, isA<UnexpectedFailure>());
        expect(failure.cause, same(error));
        logs.expectLog(
          Level.SEVERE,
          LoggerNames.api,
          'UnexpectedFailure on GET /pokemon/4',
        );
      });
    });

    group('PRD §11.4 logging', () {
      test('success logs start and end at FINE with ms and req', () async {
        final client = _client((_) async => _json('{}'));

        await client.fetchPokemon(4);

        logs.expectLog(Level.FINE, LoggerNames.api, 'GET /pokemon/4 {req=1}');
        expect(
          logs.records.last.message,
          matches(RegExp(r'^GET /pokemon/4 → 200 \{ms=\d+, req=1\}$')),
        );
        expect(logs.records.every((r) => r.level == Level.FINE), isTrue);
      });

      test('req increments per instance and tags start and end', () async {
        final client = _client((_) async => _json('{}'));

        await client.fetchIndex();
        await client.fetchPokemon(4);
        await _client((_) async => _json('{}')).fetchSpecies(7);

        final reqs = logs.records
            .map((r) => RegExp(r'req=(\d+)').firstMatch(r.message)!.group(1))
            .toList();
        expect(reqs, ['1', '1', '2', '2', '1', '1']);
      });

      test('failure log carries the req of its request', () async {
        final client = _client((_) async => _json('', 404));

        await client.fetchPokemon(1);
        await client.fetchPokemon(2);

        logs.expectLog(Level.WARNING, LoggerNames.api, 'req=2}');
      });

      test('logs at most 200 characters of a malformed body', () async {
        final body = 'x' * 1000;
        final client = _client((_) async => _json(body));

        await client.fetchPokemon(4);

        final severe = logs.records.singleWhere((r) => r.level == Level.SEVERE);
        expect(severe.message, contains('body="${'x' * 200}"'));
        expect(severe.message, isNot(contains('x' * 201)));
      });
    });
  });

  group('shouldDecodeInIsolate (TS-12)', () {
    test('only bodies above 64 KB go to an isolate', () {
      expect(shouldDecodeInIsolate(0), isFalse);
      expect(shouldDecodeInIsolate(isolateDecodeThreshold), isFalse);
      expect(shouldDecodeInIsolate(isolateDecodeThreshold + 1), isTrue);
    });
  });

  group('decodeJsonBody', () {
    test('decodes small and large bodies identically', () async {
      final small = utf8.encode(fixture('index_151'));
      final large = utf8.encode(fixture('bulbasaur'));

      expect(await decodeJsonBody(small), jsonDecode(fixture('index_151')));
      expect(await decodeJsonBody(large), jsonDecode(fixture('bulbasaur')));
    });

    test('propagates FormatException from the isolate', () async {
      final bytes = utf8.encode('{${' ' * isolateDecodeThreshold}');

      await expectLater(decodeJsonBody(bytes), throwsFormatException);
    });
  });
}
