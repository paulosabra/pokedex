import 'package:meta/meta.dart';

/// Base type for all typed, recoverable errors in the app.
///
/// Each subtype maps to one or more PRD error codes (TE-xx). The mapping is
/// many-to-one — e.g. both [NetworkFailure] and [CacheFailure] surface TE-01.
/// [message] is a short, internal tag (not user-facing); the presentation
/// layer maps each failure to a friendly, localized message.
///
/// Implements [Exception] so the data layer can `throw` a mapped failure
/// idiomatically (and satisfy `only_throw_errors`); the repository catches it
/// and converts it back into an `Err` result.
@immutable
sealed class Failure implements Exception {
  /// Creates a [Failure] with a short internal [message].
  const Failure(this.message);

  /// A short, internal description of the failure.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

/// Connectivity loss: offline with no cache (TE-01) or offline while serving
/// stale cache (TE-02).
final class NetworkFailure extends Failure {
  /// Creates a [NetworkFailure].
  const NetworkFailure([super.message = 'offline']);
}

/// A request exceeded its connect/receive timeout (TE-06).
final class TimeoutFailure extends Failure {
  /// Creates a [TimeoutFailure].
  const TimeoutFailure([super.message = 'timeout']);
}

/// The requested resource does not exist — HTTP 404 (TE-03).
final class NotFoundFailure extends Failure {
  /// Creates a [NotFoundFailure].
  const NotFoundFailure([super.message = '404']);
}

/// The server failed to handle the request — HTTP 5xx (TE-07).
final class ServerFailure extends Failure {
  /// Creates a [ServerFailure].
  const ServerFailure([super.message = '5xx']);
}

/// The client hit the API rate limit — HTTP 429 (TE-08).
final class RateLimitFailure extends Failure {
  /// Creates a [RateLimitFailure].
  const RateLimitFailure([super.message = '429']);
}

/// A response could not be parsed or deserialized (TE-09).
final class ParsingFailure extends Failure {
  /// Creates a [ParsingFailure].
  const ParsingFailure([super.message = 'parse']);
}

/// A local cache miss or read/write error (TE-01).
final class CacheFailure extends Failure {
  /// Creates a [CacheFailure].
  const CacheFailure([super.message = 'cache']);
}
