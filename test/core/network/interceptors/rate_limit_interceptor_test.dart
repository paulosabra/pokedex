import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/network/interceptors/rate_limit_interceptor.dart';

import '../../../helpers/queue_http_adapter.dart';

void main() {
  // Zero fallback delay keeps tests fast when no Retry-After is present.
  Dio wire(QueueHttpAdapter adapter, {DateTime Function()? now}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RateLimitInterceptor(
        dio,
        fallbackDelay: Duration.zero,
        now: now ?? DateTime.now,
      ),
    );
    return dio;
  }

  ResponseBody rateLimited({String? retryAfter}) => status(
    429,
    headers: retryAfter == null
        ? null
        : {
            'retry-after': [retryAfter],
          },
  );

  group('RateLimitInterceptor', () {
    test('honors a numeric Retry-After and retries to success', () async {
      final adapter = QueueHttpAdapter([
        (_) => rateLimited(retryAfter: '0'),
        (_) => jsonOk('{}'),
      ]);
      final dio = wire(adapter);

      final response = await dio.get<dynamic>('/x');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test(
      'honors an HTTP-date Retry-After in the past (immediate retry)',
      () async {
        // now() is fixed well after the header date, so the delta is negative
        // and clamps to zero — exercising the HTTP-date parse path without
        // waiting.
        final adapter = QueueHttpAdapter([
          (_) => rateLimited(retryAfter: 'Sun, 06 Nov 1994 08:49:37 GMT'),
          (_) => jsonOk('{}'),
        ]);
        final dio = wire(adapter, now: () => DateTime.utc(2030));

        final response = await dio.get<dynamic>('/x');

        expect(response.statusCode, 200);
        expect(adapter.callCount, 2);
      },
    );

    test('falls back when Retry-After is absent', () async {
      final adapter = QueueHttpAdapter([
        (_) => rateLimited(),
        (_) => jsonOk('{}'),
      ]);
      final dio = wire(adapter);

      final response = await dio.get<dynamic>('/x');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('falls back when Retry-After is unparseable', () async {
      final adapter = QueueHttpAdapter([
        (_) => rateLimited(retryAfter: 'not-a-date'),
        (_) => jsonOk('{}'),
      ]);
      final dio = wire(adapter);

      final response = await dio.get<dynamic>('/x');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('gives up after maxRetries on persistent 429', () async {
      final adapter = QueueHttpAdapter([(_) => rateLimited(retryAfter: '0')]);
      final dio = wire(adapter);

      await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
      // 1 initial attempt + 3 retries.
      expect(adapter.callCount, 4);
    });

    test('ignores non-429 errors (does not retry)', () async {
      final adapter = QueueHttpAdapter([(_) => status(500)]);
      final dio = wire(adapter);

      await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
      expect(adapter.callCount, 1);
    });
  });
}
