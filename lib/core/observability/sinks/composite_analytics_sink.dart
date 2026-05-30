import 'dart:developer' as developer;

import 'package:meta/meta.dart';
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';

/// Fans an event out to every enabled [AnalyticsService] sink (§4.2).
///
/// An empty sink list is a valid "effectively off" configuration (e.g. a PR
/// preview: release build, analytics disabled) — `logEvent` simply no-ops.
final class CompositeAnalyticsSink implements AnalyticsService {
  /// Creates a [CompositeAnalyticsSink] fanning out to [_sinks].
  const CompositeAnalyticsSink(this._sinks);

  final List<AnalyticsService> _sinks;

  /// The fan-out targets, for assertions in tests.
  @visibleForTesting
  List<AnalyticsService> get sinks => List.unmodifiable(_sinks);

  @override
  void logEvent(AnalyticsEvent event) {
    for (final sink in _sinks) {
      // A failing vendor sink must neither abort the fan-out nor throw into the
      // caller (the AnalyticsService contract) — drop it with a notice.
      try {
        sink.logEvent(event);
      } on Object catch (error, stackTrace) {
        developer.log(
          'analytics sink failed for ${event.name}',
          name: 'observability',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
