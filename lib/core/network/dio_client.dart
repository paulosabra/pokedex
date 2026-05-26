import 'package:dio/dio.dart';
import 'package:pokedex/core/network/interceptors/logging_interceptor.dart';
import 'package:pokedex/core/network/interceptors/rate_limit_interceptor.dart';
import 'package:pokedex/core/network/interceptors/retry_interceptor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_client.g.dart';

/// Base URL for all PokéAPI v2 requests.
const pokeApiBaseUrl = 'https://pokeapi.co/api/v2/';

/// Maximum time to establish a connection before failing (TE-06).
const _connectTimeout = Duration(seconds: 10);

/// Maximum time to receive a response before failing (TE-06).
const _receiveTimeout = Duration(seconds: 15);

/// The application-scoped [Dio] for the PokéAPI. Marked `keepAlive: true` so
/// the socket pool survives provider rebuilds; disposing on rebuild would
/// silently close in-flight connections.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) => createPokeApiDio();

/// Builds the configured [Dio] used to talk to the PokéAPI.
///
/// A plain factory (kept exposed for unit tests). Interceptors are attached
/// in order: rate-limit (429 backoff), retry (transient + 5xx), then logging.
Dio createPokeApiDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: pokeApiBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    ),
  );
  dio.interceptors.addAll([
    RateLimitInterceptor(dio),
    RetryInterceptor(dio),
    const LoggingInterceptor(),
  ]);
  return dio;
}
