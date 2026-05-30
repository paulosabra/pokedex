import 'package:pokedex/core/observability/analytics_event.dart';

/// Product-analytics sink: records typed, RNF-09-safe [AnalyticsEvent]s.
///
/// Deliberately split from `ErrorReporter` (D-6) — product analytics and crash
/// reporting are different concerns with different backends and lifecycles.
/// Implementations: composite fan-out, console (debug), no-op (tests), and the
/// vendor adapters (Firebase live, PostHog dark). A single-method polymorphic
/// DI seam by design (many implementations + injected type), not a callback —
/// so `one_member_abstracts` is suppressed.
// ignore: one_member_abstracts
abstract interface class AnalyticsService {
  /// Records [event] to the underlying backend(s). Fire-and-forget; never
  /// throws into the caller.
  void logEvent(AnalyticsEvent event);
}
