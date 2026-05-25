import 'package:dio/dio.dart';

/// Honors HTTP 429 (Too Many Requests) by backing off for the server-specified
/// `Retry-After` and retrying transparently (TE-08).
///
/// `Retry-After` may be a number of seconds or an IMF-fixdate HTTP-date; both
/// are parsed. When absent or unparseable, [fallbackDelay] is used. Retries are
/// bounded by [maxRetries], tracked on [RequestOptions.extra].
class RateLimitInterceptor extends Interceptor {
  /// Creates a [RateLimitInterceptor] that re-sends requests through the given
  /// [Dio]. [now] is injectable so the HTTP-date backoff path is deterministic
  /// in tests.
  RateLimitInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.fallbackDelay = const Duration(seconds: 1),
    DateTime Function() now = DateTime.now,
    // ignore: prefer_initializing_formals (named param into a private field)
  }) : _now = now;

  final Dio _dio;
  final DateTime Function() _now;

  /// The maximum number of 429 retries before surfacing the error.
  final int maxRetries;

  /// Delay used when `Retry-After` is missing or cannot be parsed.
  final Duration fallbackDelay;

  static const _attemptKey = 'rate_limit_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 429) {
      handler.next(err);
      return;
    }

    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_retryAfter(err.response?.headers));

    final options = err.requestOptions..extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Duration _retryAfter(Headers? headers) {
    final value = headers?.value('retry-after')?.trim();
    if (value == null || value.isEmpty) return fallbackDelay;

    final seconds = int.tryParse(value);
    if (seconds != null) {
      return seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
    }

    final date = _parseHttpDate(value);
    if (date == null) return fallbackDelay;
    final delta = date.difference(_now().toUtc());
    return delta.isNegative ? Duration.zero : delta;
  }
}

const _httpMonths = <String, int>{
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

final _imfFixdate = RegExp(
  r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
);

/// Parses an IMF-fixdate HTTP-date (e.g. `Sun, 06 Nov 1994 08:49:37 GMT`) into
/// a UTC [DateTime], or `null` when the format does not match. Pure Dart so it
/// stays web-safe (no `dart:io` `HttpDate`).
DateTime? _parseHttpDate(String value) {
  final match = _imfFixdate.firstMatch(value);
  if (match == null) return null;
  final month = _httpMonths[match.group(2)];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
