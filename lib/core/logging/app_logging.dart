import 'dart:async';
import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// Destination of every [LogRecord] emitted by the app.
typedef LogSink = void Function(LogRecord record);

StreamSubscription<LogRecord>? _rootSubscription;

/// Configures the `logging` package once for the whole app (PRD §11.1).
///
/// Debug builds log everything; release builds only [Level.WARNING] and above.
/// Calling it again replaces the previous listener instead of adding another.
void configureLogging({required bool release, LogSink sink = developerSink}) {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = release ? Level.WARNING : Level.ALL;

  unawaited(_rootSubscription?.cancel());
  _rootSubscription = Logger.root.onRecord.listen(sink);
}

/// Forwards to `dart:developer` so records show up in DevTools without
/// `print`.
void developerSink(LogRecord record) {
  developer.log(
    record.message,
    name: record.loggerName,
    level: record.level.value,
    time: record.time,
    sequenceNumber: record.sequenceNumber,
    error: record.error,
    stackTrace: record.stackTrace,
  );
}
