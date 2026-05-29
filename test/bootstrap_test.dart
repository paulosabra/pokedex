import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/bootstrap.dart';
import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/observability/error_reporter.dart';

/// Records captured errors for assertions.
class _SpyReporter implements ErrorReporter {
  final List<Object> errors = [];

  @override
  void captureError(Object error, StackTrace? stackTrace, {Failure? failure}) =>
      errors.add(error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'runGuarded routes an error thrown during init to the reporter',
    () async {
      final spy = _SpyReporter();
      final boom = StateError('init failed');

      await runGuarded(() async => throw boom, () => spy);

      // Resolves C-2: a throw before runApp still reaches the fallback.
      expect(spy.errors, contains(boom));
    },
  );

  test(
    'runGuarded reads the reporter lazily (honors a post-init swap)',
    () async {
      final beforeHandover = _SpyReporter();
      final afterHandover = _SpyReporter();
      var active = beforeHandover;
      final boom = StateError('after handover');

      // Mirrors bootstrap's Sentry handover: the reporter is swapped, then an
      // error is thrown — it must reach the NEW reporter, not the original.
      await runGuarded(() async {
        active = afterHandover;
        throw boom;
      }, () => active);

      expect(beforeHandover.errors, isEmpty);
      expect(afterHandover.errors, contains(boom));
    },
  );

  test('anonymizedAnalyticsConsent disables all ad signals (D-3/RNF-09)', () {
    expect(anonymizedAnalyticsConsent.adStorageConsentGranted, isFalse);
    expect(
      anonymizedAnalyticsConsent.adPersonalizationSignalsConsentGranted,
      isFalse,
    );
    expect(anonymizedAnalyticsConsent.adUserDataConsentGranted, isFalse);
    // Only aggregate analytics storage is granted.
    expect(anonymizedAnalyticsConsent.analyticsStorageConsentGranted, isTrue);
  });

  test(
    'installCrashHandlers routes FlutterError + PlatformDispatcher errors',
    () {
      final spy = _SpyReporter();
      final previousFlutterOnError = FlutterError.onError;
      final previousPlatformOnError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutterOnError;
        PlatformDispatcher.instance.onError = previousPlatformOnError;
      });

      installCrashHandlers(spy);

      final frameworkError = Exception('framework');
      FlutterError.onError!(FlutterErrorDetails(exception: frameworkError));

      final platformError = Exception('platform');
      final handled = PlatformDispatcher.instance.onError!(
        platformError,
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(spy.errors, containsAll(<Object>[frameworkError, platformError]));
    },
  );
}
