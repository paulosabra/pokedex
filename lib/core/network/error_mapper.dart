import 'package:dio/dio.dart';
import 'package:pokedex/core/error/failure.dart';

/// Translates a transport-layer error into the app's typed [Failure].
///
/// This is the single boundary where `package:dio` error types are converted —
/// nothing above the data layer should ever see a [DioException]. A raw (or
/// dio-wrapped) [FormatException] maps to [ParsingFailure]; everything else is
/// classified from its [DioExceptionType] and HTTP status code.
Failure mapError(Object error) {
  if (error is DioException) {
    // Retrofit/dio surface a deserialization failure as a DioException whose
    // underlying [DioException.error] is the original FormatException.
    if (error.error is FormatException) return const ParsingFailure();
    return _mapDioException(error);
  }
  if (error is FormatException) return const ParsingFailure();
  // A non-transport, unknown error: classify as a generic server failure rather
  // than mislabeling it "offline" (which a NetworkFailure would imply).
  return const ServerFailure();
}

Failure _mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      return _mapStatusCode(error.response?.statusCode);
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return const ServerFailure();
  }
}

Failure _mapStatusCode(int? statusCode) {
  if (statusCode == 404) return const NotFoundFailure();
  if (statusCode == 429) return const RateLimitFailure();
  if (statusCode != null && statusCode >= 500) return const ServerFailure();
  // Other 4xx (and any unexpected code) collapse to a generic ServerFailure.
  return const ServerFailure();
}
