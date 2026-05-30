import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pokedex/core/observability/analytics_event.dart';
import 'package:pokedex/core/observability/analytics_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Product-analytics adapter for PostHog.
///
/// Dark until `POSTHOG_KEY` is set (the composite only includes it when keyed,
/// §4.1). **No-op on web for the MVP** (§6a.5): the web SDK initialises from a
/// static `web/index.html` snippet that can't read `--dart-define`, which would
/// break "dark until keyed" on previews — so web is deferred until PostHog is
/// actually enabled. The body is untestable SDK glue, excluded at the line
/// level (§6a.6).
final class PostHogAdapter implements AnalyticsService {
  /// Creates a [PostHogAdapter].
  const PostHogAdapter();

  @override
  void logEvent(AnalyticsEvent event) {
    // coverage:ignore-start
    if (kIsWeb) return; // §6a.5: web deferred.
    unawaited(
      Posthog().capture(eventName: event.name, properties: event.parameters),
    );
    // coverage:ignore-end
  }
}
