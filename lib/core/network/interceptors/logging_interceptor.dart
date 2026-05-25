import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Logs each request, response, and error to the `dart:developer` log under the
/// `http` name. Response bodies are intentionally omitted (only status + URI),
/// keeping logs compact and avoiding large payload dumps.
class LoggingInterceptor extends Interceptor {
  /// Creates a [LoggingInterceptor].
  const LoggingInterceptor();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    developer.log('→ ${options.method} ${options.uri}', name: 'http');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.uri}',
      name: 'http',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '✗ ${err.type} ${err.requestOptions.uri}',
      name: 'http',
      error: err,
    );
    handler.next(err);
  }
}
