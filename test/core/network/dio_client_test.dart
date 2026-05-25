import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex/core/network/dio_client.dart';
import 'package:pokedex/core/network/interceptors/logging_interceptor.dart';
import 'package:pokedex/core/network/interceptors/rate_limit_interceptor.dart';
import 'package:pokedex/core/network/interceptors/retry_interceptor.dart';

void main() {
  group('createPokeApiDio', () {
    test('configures base url and timeouts', () {
      final dio = createPokeApiDio();

      expect(dio.options.baseUrl, pokeApiBaseUrl);
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 15));
    });

    test('attaches the rate-limit, retry, and logging interceptors', () {
      final dio = createPokeApiDio();

      expect(dio.interceptors.whereType<RateLimitInterceptor>(), hasLength(1));
      expect(dio.interceptors.whereType<RetryInterceptor>(), hasLength(1));
      expect(dio.interceptors.whereType<LoggingInterceptor>(), hasLength(1));
    });

    test('orders interceptors rate-limit → retry → logging', () {
      // Order matters: 429 backoff is handled before generic retry, and logging
      // observes the final outcome.
      final interceptors = createPokeApiDio().interceptors.toList();
      final rateLimit = interceptors.indexWhere(
        (i) => i is RateLimitInterceptor,
      );
      final retry = interceptors.indexWhere((i) => i is RetryInterceptor);
      final logging = interceptors.indexWhere((i) => i is LoggingInterceptor);

      expect(rateLimit, lessThan(retry));
      expect(retry, lessThan(logging));
    });
  });
}
