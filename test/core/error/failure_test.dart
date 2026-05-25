import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/error/failure.dart';

void main() {
  group('Failure', () {
    test('each subtype carries its default message', () {
      expect(const NetworkFailure().message, 'offline');
      expect(const TimeoutFailure().message, 'timeout');
      expect(const NotFoundFailure().message, '404');
      expect(const ServerFailure().message, '5xx');
      expect(const RateLimitFailure().message, '429');
      expect(const ParsingFailure().message, 'parse');
      expect(const CacheFailure().message, 'cache');
    });

    test('a custom message overrides the default', () {
      expect(const NetworkFailure('custom').message, 'custom');
    });

    group('equality', () {
      test('same type and message are equal and share a hashCode', () {
        // Build the message at runtime so the two instances are NOT
        // canonicalized to the same const — this forces the structural ==
        // branch instead of the identical() short-circuit.
        final message = ['off', 'line'].join();
        final a = NetworkFailure(message);
        final b = NetworkFailure(message);

        expect(identical(a, b), isFalse);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('same type, different message are not equal', () {
        expect(const NetworkFailure('a'), isNot(const NetworkFailure('b')));
      });

      test('different types with the same message are not equal', () {
        // NetworkFailure and CacheFailure both map to TE-01 but are distinct.
        expect(const NetworkFailure('x'), isNot(const CacheFailure('x')));
      });
    });
  });
}
