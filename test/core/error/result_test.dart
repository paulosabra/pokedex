import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/error/result.dart';

void main() {
  group('Result', () {
    test('Ok carries its value', () {
      const result = Ok<int>(42);

      expect(result, isA<Result<int>>());
      expect(result.value, 42);
    });

    test('Err carries its failure', () {
      const failure = NetworkFailure();
      const result = Err<int>(failure);

      expect(result, isA<Result<int>>());
      expect(result.failure, failure);
    });

    test('can be exhaustively pattern-matched', () {
      String describe(Result<int> result) => switch (result) {
        Ok(:final value) => 'ok:$value',
        Err(:final failure) => 'err:${failure.message}',
      };

      expect(describe(const Ok(1)), 'ok:1');
      expect(describe(const Err(NotFoundFailure())), 'err:404');
    });
  });
}
