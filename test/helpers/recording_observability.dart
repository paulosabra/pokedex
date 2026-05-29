import 'package:pokedex/core/error/failure.dart';
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';
import 'package:pokedex/core/observability/error_reporter.dart';

/// Recording fakes for the observability seam used by the T-30b event-wiring
/// tests.
///
/// A recorder beats a mock here: the events under test are value-like
/// `AnalyticsEvent`s with no `==`, so capturing them in a list and asserting on
/// `name`/`parameters` is clearer (and needs no `registerFallbackValue`) than
/// matcher-based verification.
class RecordingAnalytics implements AnalyticsService {
  /// Every event logged, in order.
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  /// The events recorded with the given [name].
  List<AnalyticsEvent> named(String name) =>
      events.where((e) => e.name == name).toList();

  @override
  void logEvent(AnalyticsEvent event) => events.add(event);
}

/// A single captured `captureError` call.
typedef CapturedError = ({
  Object error,
  StackTrace? stackTrace,
  Failure? failure,
});

/// Recording fake for [ErrorReporter] — captures handled-failure reports.
class RecordingErrorReporter implements ErrorReporter {
  /// Every captured error, in order.
  final List<CapturedError> captured = <CapturedError>[];

  @override
  void captureError(Object error, StackTrace? stackTrace, {Failure? failure}) =>
      captured.add((error: error, stackTrace: stackTrace, failure: failure));
}
