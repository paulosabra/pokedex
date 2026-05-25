import 'package:dio/dio.dart';

/// Retries only *transient* failures with exponential backoff (TE-06/07).
///
/// Transient = connect/send/receive timeouts, connection errors, and 5xx
/// responses. Client errors (4xx, including 429 — handled by the rate-limit
/// interceptor) and parse errors are never retried. The attempt count rides on
/// [RequestOptions.extra] so each request is bounded independently of others.
class RetryInterceptor extends Interceptor {
  /// Creates a [RetryInterceptor] that re-sends requests through [Dio].
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 300),
  });

  final Dio _dio;

  /// The maximum number of retry attempts before giving up.
  final int maxRetries;

  /// The base backoff delay; attempt n waits `baseDelay * 2^n`.
  final Duration baseDelay;

  static const _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;

    if (!_isTransient(err) || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(baseDelay * (1 << attempt));

    final options = err.requestOptions..extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isTransient(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        return code >= 500;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
