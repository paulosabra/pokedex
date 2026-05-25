import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/network/interceptors/retry_interceptor.dart';

import '../../../helpers/queue_http_adapter.dart';

void main() {
  // The interceptor re-sends through the same Dio it is attached to, so wire
  // the adapter and interceptor onto one instance. Zero backoff keeps it fast.
  Dio wire(QueueHttpAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio, baseDelay: Duration.zero));
    return dio;
  }

  group('RetryInterceptor', () {
    test('retries transient 5xx responses then succeeds', () async {
      final adapter = QueueHttpAdapter([
        (_) => status(500),
        (_) => status(503),
        (_) => jsonOk('{}'),
      ]);
      final dio = wire(adapter);

      final response = await dio.get<dynamic>('/x');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 3);
    });

    test('retries a connection error', () async {
      final adapter = QueueHttpAdapter([
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'down',
        ),
        (_) => jsonOk('{}'),
      ]);
      final dio = wire(adapter);

      final response = await dio.get<dynamic>('/x');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('gives up after maxRetries on a persistent 5xx', () async {
      final adapter = QueueHttpAdapter([(_) => status(500)]);
      final dio = wire(adapter);

      await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
      // 1 initial attempt + 3 retries.
      expect(adapter.callCount, 4);
    });

    test('does not retry a non-transient 4xx', () async {
      final adapter = QueueHttpAdapter([(_) => status(404)]);
      final dio = wire(adapter);

      await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
      expect(adapter.callCount, 1);
    });

    test('does not retry non-transient transport errors', () async {
      for (final type in const [
        DioExceptionType.cancel,
        DioExceptionType.badCertificate,
        DioExceptionType.unknown,
      ]) {
        final adapter = QueueHttpAdapter([
          (options) => throw DioException(requestOptions: options, type: type),
        ]);
        final dio = wire(adapter);

        await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
        expect(adapter.callCount, 1, reason: '$type must not be retried');
      }
    });
  });
}
