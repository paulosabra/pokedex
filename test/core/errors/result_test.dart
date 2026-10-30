import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/errors/app_failure.dart';
import 'package:pokedex/core/errors/result.dart';

void main() {
  group('Result', () {
    String render(Result<int> result) => switch (result) {
      Ok(:final value) => 'ok $value',
      Err(:final failure) => 'err ${failure.userMessage}',
    };

    test('TS-06 Ok carries the value', () {
      const Result<int> result = Ok(25);

      expect(result, isA<Ok<int>>());
      expect((result as Ok<int>).value, 25);
      expect(render(result), 'ok 25');
    });

    test('TS-06 Err carries the AppFailure', () {
      const failure = NotFoundFailure();
      const Result<int> result = Err(failure);

      expect(result, isA<Err<int>>());
      expect((result as Err<int>).failure, same(failure));
      expect(render(result), "err We couldn't find this Pokémon.");
    });

    test('TS-06 switch over Ok/Err is exhaustive without default', () {
      final results = <Result<int>>[const Ok(1), const Err(TimeoutFailure())];

      expect(results.map(render), [
        'ok 1',
        'err This is taking longer than usual. Please try again.',
      ]);
    });
  });
}
