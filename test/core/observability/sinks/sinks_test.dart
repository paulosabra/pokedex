import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';
import 'package:pokedex/core/observability/sinks/composite_analytics_sink.dart';
import 'package:pokedex/core/observability/sinks/console_sink.dart';
import 'package:pokedex/core/observability/sinks/noop_sink.dart';

/// Records the events it receives, for fan-out assertions.
class _RecordingSink implements AnalyticsService {
  final List<AnalyticsEvent> events = [];

  @override
  void logEvent(AnalyticsEvent event) => events.add(event);
}

/// Throws on every event, to verify the composite isolates sink failures.
class _ThrowingSink implements AnalyticsService {
  @override
  void logEvent(AnalyticsEvent event) => throw Exception('sink down');
}

void main() {
  const event = SortChanged(criteria: 'numberAsc');

  group('CompositeAnalyticsSink', () {
    test('fans an event out to every sink in order', () {
      final first = _RecordingSink();
      final second = _RecordingSink();
      CompositeAnalyticsSink([first, second]).logEvent(event);
      expect(first.events, [event]);
      expect(second.events, [event]);
    });

    test('with no sinks is an effective no-op', () {
      expect(
        () => const CompositeAnalyticsSink([]).logEvent(event),
        returnsNormally,
      );
    });

    test('isolates a throwing sink — fan-out continues, never throws', () {
      final survivor = _RecordingSink();
      final sink = CompositeAnalyticsSink([_ThrowingSink(), survivor]);

      expect(() => sink.logEvent(event), returnsNormally);
      // The failing sink must not starve the ones after it.
      expect(survivor.events, [event]);
    });
  });

  test('NoopAnalyticsSink ignores events', () {
    expect(() => const NoopAnalyticsSink().logEvent(event), returnsNormally);
  });

  test('ConsoleAnalyticsSink logs without throwing', () {
    expect(
      () => const ConsoleAnalyticsSink().logEvent(event),
      returnsNormally,
    );
  });
}
