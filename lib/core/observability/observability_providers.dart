import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart'
    show immutable, kReleaseMode, visibleForTesting;
import 'package:pokedex/core/observability/adapters/firebase_analytics_adapter.dart';
import 'package:pokedex/core/observability/adapters/posthog_adapter.dart';
import 'package:pokedex/core/observability/analytics_service.dart';
import 'package:pokedex/core/observability/error_reporter.dart';
import 'package:pokedex/core/observability/sinks/composite_analytics_sink.dart';
import 'package:pokedex/core/observability/sinks/console_sink.dart';
import 'package:pokedex/core/observability/sinks/noop_sink.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'observability_providers.g.dart';

/// Runtime observability configuration, read once from `--dart-define`
/// (§4.1). The single source of truth across local dev, CI build, and runtime.
@immutable
class ObservabilityConfig {
  /// Creates an [ObservabilityConfig].
  const ObservabilityConfig({
    required this.analyticsEnabled,
    required this.sentryDsn,
    required this.posthogKey,
    required this.posthogHost,
    required this.environment,
  });

  /// Reads the config from compile-time `--dart-define` values (§4.1).
  ///
  /// `ANALYTICS_ENABLED` cannot vary by build mode via a `fromEnvironment`
  /// default — "on in release" is achieved by the deploy workflow passing
  /// `--dart-define=ANALYTICS_ENABLED=true`, not by a default here.
  factory ObservabilityConfig.fromEnvironment() => const ObservabilityConfig(
    analyticsEnabled: bool.fromEnvironment('ANALYTICS_ENABLED'),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
    posthogKey: String.fromEnvironment('POSTHOG_KEY'),
    posthogHost: String.fromEnvironment(
      'POSTHOG_HOST',
      defaultValue: 'https://us.i.posthog.com',
    ),
    environment: String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    ),
  );

  /// Master analytics switch.
  final bool analyticsEnabled;

  /// Sentry DSN; empty ⇒ Sentry stays dark.
  final String sentryDsn;

  /// PostHog project key; empty ⇒ PostHog stays dark.
  final String posthogKey;

  /// PostHog ingestion endpoint.
  // TODO(paulosabra): wire posthogHost into PostHog init when the web/native
  // SDK setup lands (T-31); read here now so the flag surface is complete.
  final String posthogHost;

  /// Deployment environment tag (`development`/`preview`/`production`).
  final String environment;

  /// Firebase ships on whenever analytics is enabled (§4.1).
  bool get firebaseEnabled => analyticsEnabled;
}

/// The active [AnalyticsService]. Defaults to [NoopAnalyticsSink] so
/// `flutter test` and any un-bootstrapped scope never emit (§4.2);
/// `bootstrap()` overrides this with [buildAnalyticsSink] in production.
@riverpod
AnalyticsService analyticsService(Ref ref) => const NoopAnalyticsSink();

/// The active [ErrorReporter]. Defaults to [NoopErrorReporter] (§4.2);
/// `bootstrap()` overrides it with the console or Sentry reporter.
@riverpod
ErrorReporter errorReporter(Ref ref) => const NoopErrorReporter();

/// Builds the analytics fan-out for [config] per the §4.2 truth table:
/// ConsoleSink in non-release builds, Firebase when analytics is enabled, and
/// PostHog when additionally keyed. An empty list (release + analytics off,
/// e.g. a preview) yields an effectively-off composite.
///
/// A dark vendor logs a one-line notice rather than silently disappearing.
///
/// The vendor adapters are created through factories so tests can substitute
/// fakes — `FirebaseAnalytics.instance` would otherwise throw without a live
/// Firebase app, making the selection logic untestable.
AnalyticsService buildAnalyticsSink(
  ObservabilityConfig config, {
  @visibleForTesting AnalyticsService Function()? firebaseAdapter,
  @visibleForTesting AnalyticsService Function()? posthogAdapter,
}) {
  final makeFirebase =
      firebaseAdapter ??
      () => FirebaseAnalyticsAdapter(FirebaseAnalytics.instance);
  final makePostHog = posthogAdapter ?? PostHogAdapter.new;

  final sinks = <AnalyticsService>[
    if (!kReleaseMode) const ConsoleAnalyticsSink(),
    if (config.firebaseEnabled) makeFirebase(),
  ];

  if (config.analyticsEnabled && config.posthogKey.isNotEmpty) {
    sinks.add(makePostHog());
  } else if (config.analyticsEnabled) {
    developer.log('PostHog dark (empty POSTHOG_KEY)', name: 'observability');
  }

  return CompositeAnalyticsSink(sinks);
}

/// The provider overrides `bootstrap()` installs so the running app uses the
/// real analytics fan-out and the chosen error [reporter] (§6a.4).
List<Override> observabilityOverrides(
  ObservabilityConfig config,
  ErrorReporter reporter,
) => [
  analyticsServiceProvider.overrideWithValue(buildAnalyticsSink(config)),
  errorReporterProvider.overrideWithValue(reporter),
];
