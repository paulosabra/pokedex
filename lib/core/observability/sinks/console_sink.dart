import 'dart:developer' as developer;

import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';

/// Logs events to the dev console — the debug-run default (§4.2). Never active
/// in release builds (the composite omits it when `kReleaseMode`).
final class ConsoleAnalyticsSink implements AnalyticsService {
  /// Creates a [ConsoleAnalyticsSink].
  const ConsoleAnalyticsSink();

  @override
  void logEvent(AnalyticsEvent event) {
    developer.log('${event.name} ${event.parameters}', name: 'analytics');
  }
}
