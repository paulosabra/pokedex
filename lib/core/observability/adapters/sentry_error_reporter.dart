import 'dart:async';

import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/observability/error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash/error adapter backed by Sentry.
///
/// Only constructed when `SENTRY_DSN` is non-empty (bootstrap's keyed path,
/// §6a.4), where Sentry also owns the global `FlutterError`/`PlatformDispatcher`
/// hooks via its `appRunner`. The body is untestable SDK glue, excluded at the
/// line level (§6a.6).
final class SentryErrorReporter implements ErrorReporter {
  /// Creates a [SentryErrorReporter].
  const SentryErrorReporter();

  @override
  void captureError(Object error, StackTrace? stackTrace, {Failure? failure}) {
    // coverage:ignore-start
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        // Tag with the typed failure so the crash is grouped/filterable by its
        // failure mode. The failure→TE-code mapping is wired in T-30b.
        withScope: failure == null
            ? null
            : (scope) => scope.setTag('failure', failure.message),
      ),
    );
    // coverage:ignore-end
  }
}
