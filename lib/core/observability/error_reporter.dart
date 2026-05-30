import 'dart:developer' as developer;

import 'package:pokedex/core/error/failure.dart';

/// Crash/error sink: captures uncaught and handled errors for diagnostics.
///
/// Split from `AnalyticsService` (D-6). Implementations: console (debug),
/// no-op (tests), and the Sentry adapter (dark until `SENTRY_DSN`). A
/// single-method polymorphic DI seam by design (many implementations +
/// injected type), not a callback — so `one_member_abstracts` is suppressed.
// ignore: one_member_abstracts
abstract interface class ErrorReporter {
  /// Captures [error] with its [stackTrace]. [failure] carries the app's typed
  /// `Failure` when the error originated from a known failure mode, so a
  /// reporter can tag it with the PRD TE code.
  void captureError(Object error, StackTrace? stackTrace, {Failure? failure});
}

/// Drops every error — the default under `flutter test` so the suite never
/// emits to a backend or the console.
final class NoopErrorReporter implements ErrorReporter {
  /// Creates a [NoopErrorReporter].
  const NoopErrorReporter();

  @override
  void captureError(
    Object error,
    StackTrace? stackTrace, {
    Failure? failure,
  }) {}
}

/// Logs errors to the dev console — the debug-run / dark-path default.
final class ConsoleErrorReporter implements ErrorReporter {
  /// Creates a [ConsoleErrorReporter].
  const ConsoleErrorReporter();

  @override
  void captureError(
    Object error,
    StackTrace? stackTrace, {
    Failure? failure,
  }) {
    developer.log(
      failure == null ? 'error' : 'error (${failure.message})',
      name: 'observability',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
