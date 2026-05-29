import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';

/// Live analytics adapter forwarding events to Firebase Analytics.
///
/// Only constructed when `ANALYTICS_ENABLED` is true (§4.2); consent is
/// anonymized in `bootstrap()` (D-3) before any event is logged. The body is a
/// thin, untestable forward to the SDK — the event→`(name, parameters)`
/// mapping it relies on is covered by `AnalyticsEvent`'s own tests — so it is
/// excluded from coverage at the line level (§6a.6).
final class FirebaseAnalyticsAdapter implements AnalyticsService {
  /// Creates a [FirebaseAnalyticsAdapter] over [_analytics].
  const FirebaseAnalyticsAdapter(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void logEvent(AnalyticsEvent event) {
    // coverage:ignore-start
    unawaited(
      _analytics.logEvent(name: event.name, parameters: event.parameters),
    );
    // coverage:ignore-end
  }
}
