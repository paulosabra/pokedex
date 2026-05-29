import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokedex/core/observability/adapters/sentry_error_reporter.dart';
import 'package:pokedex/core/observability/error_reporter.dart';
import 'package:pokedex/core/observability/observability_providers.dart';
import 'package:pokedex/firebase_options.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Anonymized Firebase Analytics consent (D-3 / RNF-09): ad, ad-personalization
/// (Consent Mode v2), and ad-user-data (Consent Mode v2) signals are all OFF;
/// only aggregate `analytics-storage` is ON. A named const so the policy is
/// asserted by a test independently of the untestable `setConsent` SDK call.
typedef AnalyticsConsent = ({
  bool adStorageConsentGranted,
  bool adPersonalizationSignalsConsentGranted,
  bool adUserDataConsentGranted,
  bool analyticsStorageConsentGranted,
});

/// The anonymized consent applied at startup (see [AnalyticsConsent]).
@visibleForTesting
const AnalyticsConsent anonymizedAnalyticsConsent = (
  adStorageConsentGranted: false,
  adPersonalizationSignalsConsentGranted: false,
  adUserDataConsentGranted: false,
  analyticsStorageConsentGranted: true,
);

/// Boots the app inside an error-guarded zone wired to observability (C-2).
///
/// A synchronous fallback reporter ([ConsoleErrorReporter]) is assigned BEFORE
/// any `await`, so the zone's `onError` always has a live target even if
/// initialization throws. Crash-capture ownership is single:
///
/// - **Dark path** (no `SENTRY_DSN`): we install `FlutterError.onError` +
///   `PlatformDispatcher.onError` ([installCrashHandlers]) and the guarded zone
///   forwards to the console reporter.
/// - **Keyed path**: Sentry owns those global hooks and its own guarded zone
///   via `appRunner`; we drop the outer zone's fallback to a no-op on handover
///   so a post-handover error is never reported twice.
///
/// The body is untestable orchestration (real Firebase/Sentry init + `runApp`)
/// and is excluded from coverage; the testable pieces it composes —
/// [runGuarded], [installCrashHandlers], `anonymizedAnalyticsConsent`, and
/// `buildAnalyticsSink` — are unit tested directly (§6a.6).
// coverage:ignore-start
Future<void> bootstrap(Widget Function() builder) async {
  // The reporter backing the OUTER guarded zone. Console until something else
  // owns capture; never the app-facing reporter on the keyed path.
  ErrorReporter zoneFallback = const ConsoleErrorReporter();
  await runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = ObservabilityConfig.fromEnvironment();

    if (config.firebaseEnabled) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Named booleans (NOT a ConsentStatus enum); see the const above.
      await FirebaseAnalytics.instance.setConsent(
        adStorageConsentGranted:
            anonymizedAnalyticsConsent.adStorageConsentGranted,
        adPersonalizationSignalsConsentGranted:
            anonymizedAnalyticsConsent.adPersonalizationSignalsConsentGranted,
        adUserDataConsentGranted:
            anonymizedAnalyticsConsent.adUserDataConsentGranted,
        analyticsStorageConsentGranted:
            anonymizedAnalyticsConsent.analyticsStorageConsentGranted,
      );
    }

    if (config.sentryDsn.isNotEmpty) {
      await SentryFlutter.init(
        (options) => options.dsn = config.sentryDsn,
        appRunner: () {
          // Sentry now owns uncaught-error capture (its hooks + own zone), so
          // the outer zone must not re-report — hand it a no-op.
          zoneFallback = const NoopErrorReporter();
          _runApp(config, const SentryErrorReporter(), builder);
        },
      );
    } else {
      developer.log('Sentry dark (empty SENTRY_DSN)', name: 'observability');
      installCrashHandlers(zoneFallback);
      _runApp(config, zoneFallback, builder);
    }
  }, () => zoneFallback);
}

void _runApp(
  ObservabilityConfig config,
  ErrorReporter reporter,
  Widget Function() builder,
) {
  runApp(
    ProviderScope(
      overrides: observabilityOverrides(config, reporter),
      child: builder(),
    ),
  );
}
// coverage:ignore-end

/// Runs [body] in an error-guarded zone, routing both boot and runtime failures
/// to the current reporter from [reporter] (read lazily so a Sentry handover is
/// honored). Surfacing as a named function keeps the zone wiring testable.
///
/// Two channels, because a guarded zone does NOT capture errors you `await`:
/// - the explicit `try`/`catch` reports synchronous boot/init failures (the
///   `await body()` path) that would otherwise rethrow out of `main` (C-2);
/// - the zone's `onError` reports runtime uncaught errors raised after `body`
///   hands control to the app (unawaited futures, timers, callbacks).
@visibleForTesting
Future<void> runGuarded(
  Future<void> Function() body,
  ErrorReporter Function() reporter,
) async {
  await runZonedGuarded(
    () async {
      try {
        await body();
      } on Object catch (error, stackTrace) {
        reporter().captureError(error, stackTrace);
      }
    },
    (error, stack) => reporter().captureError(error, stack),
  );
}

/// Installs global crash hooks routing framework + platform errors to
/// [reporter]. Used only on the dark (non-Sentry) path; Sentry installs its own
/// equivalents via `appRunner`.
@visibleForTesting
void installCrashHandlers(ErrorReporter reporter) {
  FlutterError.onError = (details) =>
      reporter.captureError(details.exception, details.stack);
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.captureError(error, stack);
    return true;
  };
}
