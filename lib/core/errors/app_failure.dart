/// Domain failure taxonomy (PRD §10.1). Technical details in [cause] and
/// [stackTrace] are for logging only and never reach [userMessage].
sealed class AppFailure {
  const AppFailure({this.cause, this.stackTrace});

  final Object? cause;
  final StackTrace? stackTrace;

  String get userMessage;
}

const _genericMessage = 'Something went wrong on our side. Please try again.';

final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause, super.stackTrace});

  @override
  String get userMessage =>
      'No internet connection. Check your network and try again.';
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.cause, super.stackTrace});

  @override
  String get userMessage =>
      'This is taking longer than usual. Please try again.';
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.cause, super.stackTrace});

  @override
  String get userMessage => "We couldn't find this Pokémon.";
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({super.cause, super.stackTrace});

  @override
  String get userMessage => 'Too many requests. Wait a moment and try again.';
}

final class ServerFailure extends AppFailure {
  const ServerFailure(this.statusCode, {super.cause, super.stackTrace});

  final int statusCode;

  @override
  String get userMessage => _genericMessage;
}

final class ParsingFailure extends AppFailure {
  const ParsingFailure({super.cause, super.stackTrace});

  @override
  String get userMessage => _genericMessage;
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.cause, super.stackTrace});

  @override
  String get userMessage => _genericMessage;
}
