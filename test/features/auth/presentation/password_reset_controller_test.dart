import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/password_reset_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;

  PasswordResetController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(passwordResetControllerProvider.notifier);
  }

  void answerWith(Result<void> result) {
    when(
      () => repository.resetPassword(
        token: any(named: 'token'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockAuthRepository();
  });

  test('GivenAcceptedReset_WhenSubmitted_ThenStateIsSucceeded', () async {
    // Given
    answerWith(const Success<void>(null));
    final controller = controllerUnderTest();

    // When
    await controller.submit(token: 'reset-token', newPassword: 'new-secret');

    // Then
    expect(
      container.read(passwordResetControllerProvider),
      isA<ResetSucceeded>(),
    );
  });

  test('GivenAResetToken_WhenSubmitted_ThenTokenAndPasswordAreSent', () async {
    // Given
    answerWith(const Success<void>(null));
    final controller = controllerUnderTest();

    // When
    await controller.submit(token: 'reset-token', newPassword: 'new-secret');

    // Then
    verify(
      () => repository.resetPassword(
        token: 'reset-token',
        newPassword: 'new-secret',
      ),
    ).called(1);
  });

  // AF-04b — a token the API will not accept.
  test('GivenRejectedToken_WhenSubmitted_ThenApiErrorsAreKept', () async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The reset token has expired.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.submit(token: 'stale', newPassword: 'new-secret');

    // Then
    final state = container.read(passwordResetControllerProvider);
    expect((state as ResetFailed).failure.errors, <String>[
      'The reset token has expired.',
    ]);
  });

  // AF-04d — a password the policy refuses.
  test('GivenRejectedPassword_WhenSubmitted_ThenApiErrorsAreKept', () async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Password must be at least 8 characters.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.submit(token: 'reset-token', newPassword: 'short');

    // Then
    final state = container.read(passwordResetControllerProvider);
    expect((state as ResetFailed).failure.errors, <String>[
      'Password must be at least 8 characters.',
    ]);
  });

  test('GivenTransportFailure_WhenSubmitted_ThenStateIsFailed', () async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.submit(token: 'reset-token', newPassword: 'new-secret');

    // Then
    final state = container.read(passwordResetControllerProvider);
    expect((state as ResetFailed).failure.kind, FailureKind.network);
  });

  // A reset token is spent by using it, so a double submission must not send
  // the same one twice.
  test(
    'GivenResetInFlight_WhenSubmittedAgain_ThenOnlyOneRequestIsSent',
    () async {
      // Given
      final pending = Completer<Result<void>>();
      when(
        () => repository.resetPassword(
          token: any(named: 'token'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) => pending.future);
      final controller = controllerUnderTest();

      // When
      final first = controller.submit(
        token: 'reset-token',
        newPassword: 'new-secret',
      );
      final second = controller.submit(
        token: 'reset-token',
        newPassword: 'new-secret',
      );
      pending.complete(const Success<void>(null));
      await Future.wait<void>(<Future<void>>[first, second]);

      // Then
      verify(
        () => repository.resetPassword(
          token: 'reset-token',
          newPassword: 'new-secret',
        ),
      ).called(1);
    },
  );
}
