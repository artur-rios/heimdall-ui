import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';

void main() {
  test('GivenSuccess_WhenFolded_ThenSuccessBranchRuns', () {
    // Given
    const Result<int> result = Success<int>(7);

    // When
    final folded = result.fold(
      onSuccess: (value) => 'ok:$value',
      onFailure: (failure) => 'error',
    );

    // Then
    expect(folded, 'ok:7');
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, 7);
    expect(result.failureOrNull, isNull);
  });

  test('GivenFailure_WhenFolded_ThenFailureBranchCarriesTheErrors', () {
    // Given
    const failure = Failure(
      kind: FailureKind.validation,
      errors: <String>['Name is required'],
    );
    const Result<int> result = FailureResult<int>(failure);

    // When
    final folded = result.fold(
      onSuccess: (value) => 'ok',
      onFailure: (f) => f.errors.join(),
    );

    // Then
    expect(folded, 'Name is required');
    expect(result.isSuccess, isFalse);
    expect(result.valueOrNull, isNull);
  });

  test('GivenFailureWithoutMessage_WhenDisplayed_ThenFirstErrorIsUsed', () {
    // Given
    const failure = Failure(
      kind: FailureKind.conflict,
      errors: <String>['Name already exists', 'Second error'],
    );

    // When
    final message = failure.displayMessage;

    // Then
    expect(message, 'Name already exists');
  });

  test('GivenFailureWithNothingToSay_WhenDisplayed_ThenFallbackIsUsed', () {
    // Given
    const failure = Failure(kind: FailureKind.unknown, errors: <String>[]);

    // When
    final message = failure.displayMessage;

    // Then
    expect(message, 'Something went wrong.');
  });

  // A network failure built anywhere but the envelope still reads as one.
  test('GivenANetworkFailureWithNothingToSay_WhenDisplayed_ThenItSaysTheApiIsUnreachable', () {
    // Given
    const failure = Failure(kind: FailureKind.network, errors: <String>[]);

    // When
    final message = failure.displayMessage;

    // Then
    expect(message, kUnreachableMessage);
  });

  test(
    'GivenARateLimitWithoutErrors_WhenDisplayed_ThenItSaysTryAgainLater',
    () {
      // Given
      const failure = Failure(
        kind: FailureKind.rateLimited,
        errors: <String>[],
      );

      // When
      final message = failure.displayMessage;

      // Then
      expect(message, 'Too many requests. Try again later.');
    },
  );

  test('GivenARateLimitWithRetryAfter_WhenDisplayed_ThenItNamesTheSeconds', () {
    // Given
    const failure = Failure(
      kind: FailureKind.rateLimited,
      errors: <String>[],
      retryAfter: Duration(seconds: 5),
    );

    // When
    final message = failure.displayMessage;

    // Then
    expect(message, 'Too many requests. Try again in 5 seconds.');
  });

  test('GivenOneSecond_WhenHinted_ThenTheWordIsSingular', () {
    // Given
    const failure = Failure(
      kind: FailureKind.rateLimited,
      errors: <String>[],
      retryAfter: Duration(seconds: 1),
    );

    // When
    final hint = failure.retryHint;

    // Then
    expect(hint, 'Try again in 1 second.');
  });

  // FR-UX-09 — an account email's cooldown or daily window can be minutes or
  // hours away, which a count of seconds would make hard to read.
  for (final (seconds, expected) in <(int, String)>[
    (59, 'Try again in 59 seconds.'),
    (60, 'Try again in 1 minute.'),
    (61, 'Try again in 2 minutes.'),
    (300, 'Try again in 5 minutes.'),
    (3599, 'Try again in 60 minutes.'),
    (3600, 'Try again in 1 hour.'),
    (3601, 'Try again in 2 hours.'),
    (86400, 'Try again in 24 hours.'),
  ]) {
    test('GivenALongWait_WhenHinted_ThenItIsRoundedUpToAReadableUnit: '
        '$seconds', () {
      // Given
      final failure = Failure(
        kind: FailureKind.rateLimited,
        errors: const <String>[],
        retryAfter: Duration(seconds: seconds),
      );

      // When
      final hint = failure.retryHint;

      // Then
      expect(hint, expected);
    });
  }

  // A Failure built anywhere else is held to the same bound: what a pause is
  // timed by is never zero, negative, or longer than a day.
  for (final (wait, expected, hint) in <(Duration?, Duration?, String?)>[
    (null, null, null),
    (Duration.zero, null, null),
    (const Duration(seconds: -1), null, null),
    (
      const Duration(seconds: 90),
      const Duration(seconds: 90),
      'Try again in 2 minutes.',
    ),
    (
      const Duration(days: 400),
      const Duration(days: 1),
      'Try again in 24 hours.',
    ),
  ]) {
    test('GivenARetryAfter_WhenPaused_ThenItIsBounded: $wait', () {
      // Given
      final failure = Failure(
        kind: FailureKind.rateLimited,
        errors: const <String>[],
        retryAfter: wait,
      );

      // When
      final pause = failure.pause;

      // Then
      expect(pause, expected);
      expect(failure.retryHint, hint);
    });
  }

  for (final (seconds, expected) in <(int, String)>[
    (1, '1 second'),
    (59, '59 seconds'),
    (60, '1 minute'),
    (3600, '1 hour'),
  ]) {
    test('GivenAWait_WhenDescribed_ThenItIsReadable: $seconds', () {
      // Given
      final wait = Duration(seconds: seconds);

      // When
      final described = describeWait(wait);

      // Then
      expect(described, expected);
    });
  }
}
