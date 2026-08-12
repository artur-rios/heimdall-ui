/// The kind of a failure, which is what decides how the interface reacts to it.
enum FailureKind {
  validation,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  network,
  unknown,
}

/// A failed outcome, carrying the API's own error messages when it produced any.
///
/// The strings in [errors] come straight from the response envelope and are
/// shown as returned, so what a user reads matches what an operator finds in
/// the API's logs.
class Failure {
  const Failure({required this.kind, required this.errors, this.message});

  final FailureKind kind;
  final List<String> errors;
  final String? message;

  /// The single line worth showing when there is no field to attach errors to.
  String get displayMessage =>
      message ?? (errors.isNotEmpty ? errors.first : 'Something went wrong.');

  @override
  String toString() => 'Failure($kind, $errors, $message)';
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
