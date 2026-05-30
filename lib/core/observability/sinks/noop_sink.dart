import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';

/// Drops every event — the default `AnalyticsService` under `flutter test`
/// (§4.2), so the suite never spams the console or touches the network.
final class NoopAnalyticsSink implements AnalyticsService {
  /// Creates a [NoopAnalyticsSink].
  const NoopAnalyticsSink();

  @override
  void logEvent(AnalyticsEvent event) {}
}
