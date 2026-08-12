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
}
