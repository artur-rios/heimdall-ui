/// The kind of a failure, which is what decides how the interface reacts to it.
enum FailureKind {
  validation,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  rateLimited,
  server,
  network,
  unknown,
}

/// What a person is told when the API could not be reached at all: no
/// connection, a refused connection, or a timeout. Such a failure carries no
/// words of the API's own, and the HTTP library's are written for developers.
const String kUnreachableMessage =
    'Could not reach the API. Check your connection and try again.';

/// What a person is told when the API answered, but not with anything the
/// client could read: a 2xx body of the wrong shape, say. It is not the
/// person's connection and not anything they can correct, so the screen offers
/// Retry (FR-UX-07).
const String kUnexpectedResponseMessage =
    'The API returned an unexpected response.';

/// The longest a client pauses for a `Retry-After`: the account-email
/// budget's daily window. A longer wait is held to it, so no timer is ever
/// set for longer, and none overflows.
const Duration kMaxRetryAfter = Duration(days: 1);

/// [wait] as a person reads it: seconds under a minute, minutes under an
/// hour, hours beyond, each rounded up.
String describeWait(Duration wait) {
  final seconds = wait.inSeconds;

  String count(int amount, String unit) =>
      amount == 1 ? '1 $unit' : '$amount ${unit}s';

  return switch (seconds) {
    < 60 => count(seconds, 'second'),
    < 3600 => count((seconds + 59) ~/ 60, 'minute'),
    _ => count((seconds + 3599) ~/ 3600, 'hour'),
  };
}

/// A failed outcome, carrying the API's own error messages when it produced any.
///
/// The strings in [errors] come straight from the response envelope and are
/// shown as returned, so what a user reads matches what an operator finds in
/// the API's logs.
class Failure {
  const Failure({
    required this.kind,
    required this.errors,
    this.message,
    this.retryAfter,
  });

  final FailureKind kind;
  final List<String> errors;
  final String? message;

  /// How long the API asked the caller to wait, from a `429`'s `Retry-After`.
  /// `null` when the response carried none, as an older API's account-email
  /// cooldown did: its message says how long instead.
  final Duration? retryAfter;

  /// How long to hold back a control that would only be refused again:
  /// [retryAfter] held to [kMaxRetryAfter], or `null` when there is no
  /// positive wait. Every pause is timed by this, never by [retryAfter].
  Duration? get pause => switch (retryAfter) {
    final Duration wait when wait <= Duration.zero => null,
    final Duration wait when wait > kMaxRetryAfter => kMaxRetryAfter,
    final Duration? wait => wait,
  };

  /// "Try again in N seconds." when the API said how long to wait, else `null`.
  ///
  /// A wait of a minute or more is named in minutes, and one of an hour or
  /// more in hours (see [describeWait]): an account email's cooldown is
  /// minutes long, and its daily window hours.
  String? get retryHint => switch (pause) {
    final Duration wait => 'Try again in ${describeWait(wait)}.',
    null => null,
  };

  /// The single line worth showing when there is no field to attach errors to.
  String get displayMessage =>
      message ??
      (errors.isNotEmpty
          ? errors.first
          : kind == FailureKind.rateLimited
          ? 'Too many requests. ${retryHint ?? 'Try again later.'}'
          : kind == FailureKind.network
          ? kUnreachableMessage
          : 'Something went wrong.');

  @override
  String toString() => 'Failure($kind, $errors, $message, $retryAfter)';
}

/// The outcome of an operation that can fail without throwing.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    FailureResult<T>(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    FailureResult<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;
}
