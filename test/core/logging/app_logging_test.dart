import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pokedex/core/logging/app_logging.dart';
import 'package:pokedex/core/logging/loggers.dart';

import '../../helpers/log_recorder.dart';

void main() {
  late List<LogRecord> sunk;

  setUp(() => sunk = []);

  tearDown(() => configureLogging(release: false, sink: (_) {}));

  group('LoggerNames', () {
    test('exposes the root and the seven children of Tech Spec §9', () {
      expect(LoggerNames.all, [
        'pokedex',
        'pokedex.app',
        'pokedex.api',
        'pokedex.repository',
        'pokedex.storage',
        'pokedex.controller.list',
        'pokedex.controller.detail',
        'pokedex.view.image',
      ]);
    });

    test('every child is nested under the root', () {
      for (final name in LoggerNames.all.skip(1)) {
        expect(Logger(name).parent?.fullName, startsWith(LoggerNames.root));
      }
    });
  });

  group('configureLogging', () {
    test('enables hierarchical logging', () {
      configureLogging(release: false, sink: sunk.add);

      expect(hierarchicalLoggingEnabled, isTrue);
    });

    test('debug logs every level', () {
      configureLogging(release: false, sink: sunk.add);

      expect(Logger.root.level, Level.ALL);
      Logger(LoggerNames.api).finest('trace');
      expect(sunk.single.message, 'trace');
    });

    test('release only logs WARNING and above', () {
      configureLogging(release: true, sink: sunk.add);

      expect(Logger.root.level, Level.WARNING);
      Logger(LoggerNames.repository)
        ..info('cache hit id=4')
        ..warning('species unavailable id=4')
        ..severe('ServerFailure 500');
      expect(sunk.map((r) => r.level), [Level.WARNING, Level.SEVERE]);
    });

    test('forwards logger name, error and stack trace to the sink', () {
      configureLogging(release: false, sink: sunk.add);
      final error = StateError('boom');
      final stackTrace = StackTrace.current;

      Logger(LoggerNames.storage).severe('open failed', error, stackTrace);

      final record = sunk.single;
      expect(record.loggerName, LoggerNames.storage);
      expect(record.level, Level.SEVERE);
      expect(record.error, same(error));
      expect(record.stackTrace, same(stackTrace));
    });

    test('is idempotent: calling twice keeps a single listener', () {
      final first = <LogRecord>[];
      configureLogging(release: false, sink: first.add);
      configureLogging(release: false, sink: sunk.add);

      Logger(LoggerNames.app).info('app started');

      expect(first, isEmpty);
      expect(sunk, hasLength(1));
    });

    test('default sink forwards to dart:developer without throwing', () {
      configureLogging(release: false);

      expect(
        () =>
            Logger(LoggerNames.app)
                .severe('global error', StateError('x'), StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('LogRecorder', () {
    test('captures records from any logger under pokedex', () {
      final logs = LogRecorder();

      Logger(LoggerNames.listController).info('sort changed: number → name');
      Logger(LoggerNames.detailController).fine('stale response discarded');

      expect(logs.records, hasLength(2));
      logs
        ..expectLog(Level.INFO, LoggerNames.listController, 'sort changed')
        ..expectLog(Level.FINE, LoggerNames.detailController, 'stale');
    });

    test('ignores loggers outside the pokedex hierarchy', () {
      final logs = LogRecorder();

      Logger('other').severe('not ours');

      logs.expectNoLogs();
    });

    test('expectNoLogs can be scoped to a logger', () {
      final logs = LogRecorder();

      Logger(LoggerNames.api).fine('GET /pokemon/4 → 200');

      logs
        ..expectNoLogs(logger: LoggerNames.repository)
        ..clear()
        ..expectNoLogs();
    });

    test('lowers the root level and restores it on tear-down', () {
      Logger.root.level = Level.WARNING;
      addTearDown(() => expect(Logger.root.level, Level.WARNING));

      LogRecorder();

      expect(Logger.root.level, Level.ALL);
    });
  });
}
