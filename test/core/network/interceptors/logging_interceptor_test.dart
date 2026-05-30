import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/network/interceptors/logging_interceptor.dart';

import '../../../helpers/queue_http_adapter.dart';

void main() {
  Dio wire(QueueHttpAdapter adapter) {
    return Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = adapter
      ..interceptors.add(const LoggingInterceptor());
  }

  group('LoggingInterceptor', () {
    test('passes a successful request/response through unchanged', () async {
      final dio = wire(QueueHttpAdapter([(_) => jsonOk('{"ok":true}')]));

      final response = await dio.get<dynamic>('/x');

      expect(response.statusCode, 200);
    });

    test('passes an error through without swallowing it', () async {
      final dio = wire(QueueHttpAdapter([(_) => status(500)]));

      await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));
    });
  });
}
