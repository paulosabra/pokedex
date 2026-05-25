import 'package:pokedex/core/error/failure.dart';

/// A typed result that is either a success ([Ok]) or a failure ([Err]).
sealed class Result<T> {
  /// Const base constructor for [Result] subtypes.
  const Result();
}

/// A successful [Result] carrying its [value].
final class Ok<T> extends Result<T> {
  /// Creates a successful [Ok] with [value].
  const Ok(this.value);

  /// The success value.
  final T value;
}

/// A failed [Result] carrying its [failure].
final class Err<T> extends Result<T> {
  /// Creates a failed [Err] with [failure].
  const Err(this.failure);

  /// The [Failure] describing what went wrong.
  final Failure failure;
}
