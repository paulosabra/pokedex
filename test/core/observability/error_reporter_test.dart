import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/observability/error_reporter.dart';

void main() {
  final error = Exception('boom');
  final stack = StackTrace.current;

  test('NoopErrorReporter swallows everything', () {
    expect(
      () => const NoopErrorReporter().captureError(error, stack),
      returnsNormally,
    );
  });

  group('ConsoleErrorReporter', () {
    test('logs an error without a failure', () {
      expect(
        () => const ConsoleErrorReporter().captureError(error, stack),
        returnsNormally,
      );
    });

    test('logs an error tagged with its failure', () {
      expect(
        () => const ConsoleErrorReporter().captureError(
          error,
          null,
          failure: const NetworkFailure(),
        ),
        returnsNormally,
      );
    });
  });
}
