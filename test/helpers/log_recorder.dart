import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pokedex/core/logging/loggers.dart';

/// Captures records emitted under `Logger('pokedex')` during a single test.
///
/// Create it inside a test or `setUp`; it enables hierarchical logging (as
/// `configureLogging` does, so only `pokedex.*` records are captured), lowers
/// [Logger.root.level] to [Level.ALL] and registers a tear-down that cancels
/// the subscription and restores the previous level.
final class LogRecorder {
  LogRecorder() {
    hierarchicalLoggingEnabled = true;
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger(LoggerNames.root).onRecord.listen(_records.add);
    addTearDown(() async {
      await subscription.cancel();
      Logger.root.level = previousLevel;
    });
  }

  final List<LogRecord> _records = [];

  List<LogRecord> get records => List.unmodifiable(_records);

  void clear() => _records.clear();

  /// Asserts that at least one record has [level], was emitted by [logger]
  /// and its message contains [contains].
  void expectLog(Level level, String logger, String contains) {
    final match = _records.any(
      (r) =>
          r.level == level &&
          r.loggerName == logger &&
          r.message.contains(contains),
    );
    expect(
      match,
      isTrue,
      reason:
          'No $level record on "$logger" containing "$contains". '
          'Recorded:\n${_records.map(_describe).join('\n')}',
    );
  }

  /// Asserts that no record was emitted by [logger] (or anywhere, if null).
  void expectNoLogs({String? logger}) {
    final matching = logger == null
        ? _records
        : _records.where((r) => r.loggerName == logger).toList();
    expect(matching.map(_describe), isEmpty);
  }

  static String _describe(LogRecord r) =>
      '  ${r.level} ${r.loggerName}: ${r.message}';
}
