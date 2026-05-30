import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';
import 'package:pokedex/core/observability/error_reporter.dart';
import 'package:pokedex/core/observability/observability_providers.dart';
import 'package:pokedex/core/observability/sinks/composite_analytics_sink.dart';
import 'package:pokedex/core/observability/sinks/console_sink.dart';
import 'package:pokedex/core/observability/sinks/noop_sink.dart';

/// Records events so truth-table membership can be asserted by fan-out.
class _RecordingSink implements AnalyticsService {
  final List<AnalyticsEvent> events = [];

  @override
  void logEvent(AnalyticsEvent event) => events.add(event);
}

ObservabilityConfig _config({
  bool analyticsEnabled = false,
  String posthogKey = '',
}) => ObservabilityConfig(
  analyticsEnabled: analyticsEnabled,
  sentryDsn: '',
  posthogKey: posthogKey,
  posthogHost: 'https://us.i.posthog.com',
  environment: 'development',
);

void main() {
  group('ObservabilityConfig.fromEnvironment', () {
    test('uses safe defaults when no --dart-define is set', () {
      final config = ObservabilityConfig.fromEnvironment();
      expect(config.analyticsEnabled, isFalse);
      expect(config.sentryDsn, isEmpty);
      expect(config.posthogKey, isEmpty);
      expect(config.posthogHost, 'https://us.i.posthog.com');
      expect(config.environment, 'development');
      expect(config.firebaseEnabled, isFalse);
    });
  });

  group(
    'buildAnalyticsSink (§4.2 truth table; debug → Console always present)',
    () {
      final firebase = _RecordingSink();
      final posthog = _RecordingSink();

      List<AnalyticsService> sinksFor(ObservabilityConfig config) {
        final sink =
            buildAnalyticsSink(
                  config,
                  firebaseAdapter: () => firebase,
                  posthogAdapter: () => posthog,
                )
                as CompositeAnalyticsSink;
        return sink.sinks;
      }

      test('analytics off → Console only (no Firebase, no PostHog)', () {
        final sinks = sinksFor(_config());
        expect(sinks, contains(isA<ConsoleAnalyticsSink>()));
        expect(sinks, isNot(contains(firebase)));
        expect(sinks, isNot(contains(posthog)));
      });

      test('analytics on, no key → Console + Firebase; PostHog dark', () {
        final sinks = sinksFor(_config(analyticsEnabled: true));
        expect(sinks, contains(isA<ConsoleAnalyticsSink>()));
        expect(sinks, contains(firebase));
        expect(sinks, isNot(contains(posthog)));
      });

      test('analytics on + key → Console + Firebase + PostHog', () {
        final sinks = sinksFor(
          _config(analyticsEnabled: true, posthogKey: 'phc_test'),
        );
        expect(sinks, contains(isA<ConsoleAnalyticsSink>()));
        expect(sinks, contains(firebase));
        expect(sinks, contains(posthog));
      });
    },
  );

  group('providers', () {
    test('default sinks are no-ops (NoopSink under flutter test, §4.2)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(analyticsServiceProvider),
        isA<NoopAnalyticsSink>(),
      );
      expect(container.read(errorReporterProvider), isA<NoopErrorReporter>());
    });

    test(
      'observabilityOverrides wires the built sink + the given reporter',
      () {
        const reporter = ConsoleErrorReporter();
        final container = ProviderContainer(
          overrides: observabilityOverrides(_config(), reporter),
        );
        addTearDown(container.dispose);
        expect(
          container.read(analyticsServiceProvider),
          isA<CompositeAnalyticsSink>(),
        );
        expect(container.read(errorReporterProvider), same(reporter));
      },
    );
  });
}
