import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/errors/app_failure.dart';

void main() {
  group('AppFailure', () {
    group('userMessage', () {
      const generic = 'Something went wrong on our side. Please try again.';
      final cases = <String, (AppFailure, String)>{
        'Network': (
          const NetworkFailure(),
          'No internet connection. Check your network and try again.',
        ),
        'Timeout': (
          const TimeoutFailure(),
          'This is taking longer than usual. Please try again.',
        ),
        'NotFound': (const NotFoundFailure(), "We couldn't find this Pokémon."),
        'RateLimit': (
          const RateLimitFailure(),
          'Too many requests. Wait a moment and try again.',
        ),
        'Server': (const ServerFailure(503), generic),
        'Parsing': (const ParsingFailure(), generic),
        'Unexpected': (const UnexpectedFailure(), generic),
      };

      for (final MapEntry(key: name, value: (failure, expected))
          in cases.entries) {
        test('PRD-10.3 $name failure shows the PRD message', () {
          expect(failure.userMessage, expected);
        });
      }

      test('PRD-10.3 cause and stackTrace never leak into userMessage', () {
        const sentinel = 'SENTINEL_SocketException_host_lookup';
        final trace = StackTrace.fromString('#0 SENTINEL_FRAME');
        final failures = <AppFailure>[
          NetworkFailure(cause: sentinel, stackTrace: trace),
          TimeoutFailure(cause: sentinel, stackTrace: trace),
          NotFoundFailure(cause: sentinel, stackTrace: trace),
          RateLimitFailure(cause: sentinel, stackTrace: trace),
          ServerFailure(500, cause: sentinel, stackTrace: trace),
          ParsingFailure(cause: sentinel, stackTrace: trace),
          UnexpectedFailure(cause: sentinel, stackTrace: trace),
        ];

        for (final failure in failures) {
          expect(failure.userMessage, isNot(contains('SENTINEL')));
          expect(failure.cause, sentinel);
          expect(failure.stackTrace, same(trace));
        }
      });
    });

    group('ServerFailure', () {
      test('PRD-10.2 keeps the HTTP status code for logging', () {
        expect(const ServerFailure(502).statusCode, 502);
      });
    });

    group('exhaustiveness', () {
      String describe(AppFailure failure) => switch (failure) {
        NetworkFailure() => 'network',
        TimeoutFailure() => 'timeout',
        NotFoundFailure() => 'notFound',
        RateLimitFailure() => 'rateLimit',
        ServerFailure(:final statusCode) => 'server $statusCode',
        ParsingFailure() => 'parsing',
        UnexpectedFailure() => 'unexpected',
      };

      test('TS-06 switch over the 7 subtypes compiles without default', () {
        expect(describe(const ServerFailure(500)), 'server 500');
        expect(describe(const ParsingFailure()), 'parsing');
      });
    });
  });
}
