import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/email_verification_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;

  EmailVerificationController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(emailVerificationControllerProvider.notifier);
  }

  EmailVerificationState currentState() =>
      container.read(emailVerificationControllerProvider);

  void answerVerifyWith(Result<List<String>> result) {
    when(
      () => repository.verifyEmail(token: any(named: 'token')),
    ).thenAnswer((_) async => result);
  }

  void answerResendWith(Result<void> result) {
    when(
      () => repository.resendVerificationEmail(),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockAuthRepository();
  });

  test('GivenAValidToken_WhenVerified_ThenStateIsVerified', () async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>['Email verified.']));
    final controller = controllerUnderTest();

    // When
    await controller.verify('verification-token');

    // Then
    expect(currentState().verification, isA<Verified>());
  });

  test('GivenAValidToken_WhenVerified_ThenTheTokenIsSent', () async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));
    final controller = controllerUnderTest();

    // When
    await controller.verify('verification-token');

    // Then
    verify(() => repository.verifyEmail(token: 'verification-token')).called(1);
  });

  // AF-05d — an address that was already verified answers successfully, and
  // the API's own wording is what says so.
  test('GivenAlreadyVerified_WhenVerified_ThenTheApiMessagesAreKept', () async {
    // Given
    answerVerifyWith(
      const Success<List<String>>(<String>[
        'This address was already verified.',
      ]),
    );
    final controller = controllerUnderTest();

    // When
    await controller.verify('spent-token');

    // Then
    expect((currentState().verification as Verified).messages, <String>[
      'This address was already verified.',
    ]);
  });

  // AF-05a — no token means no request.
  test('GivenNoToken_WhenVerified_ThenNoRequestIsMade', () async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));
    final controller = controllerUnderTest();

    // When
    await controller.verify(null);

    // Then
    verifyNever(() => repository.verifyEmail(token: any(named: 'token')));
  });

  test('GivenAnEmptyToken_WhenVerified_ThenStateStaysIdle', () async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));
    final controller = controllerUnderTest();

    // When
    await controller.verify('');

    // Then
    expect(currentState().verification, isA<VerifyIdle>());
  });

  // AF-05b — the API refuses the token.
  test('GivenRejectedToken_WhenVerified_ThenApiErrorsAreKept', () async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The verification token has expired.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.verify('stale');

    // Then
    expect(
      (currentState().verification as VerifyRejected).failure.errors,
      <String>['The verification token has expired.'],
    );
  });

  test('GivenTransportFailure_WhenVerified_ThenStateIsRejected', () async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.verify('verification-token');

    // Then
    expect(
      (currentState().verification as VerifyRejected).failure.kind,
      FailureKind.network,
    );
  });

  // AF-05c — the resend.
  test('GivenAResendRequest_WhenSent_ThenStateIsSent', () async {
    // Given
    answerResendWith(const Success<void>(null));
    final controller = controllerUnderTest();

    // When
    await controller.resend();

    // Then
    expect(currentState().resend, isA<ResendSent>());
  });

  test('GivenRejectedResend_WhenSent_ThenApiErrorsAreKept', () async {
    // Given
    answerResendWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['This address is already verified.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.resend();

    // Then
    expect((currentState().resend as ResendRejected).failure.errors, <String>[
      'This address is already verified.',
    ]);
  });

  test(
    'GivenResendInFlight_WhenRequestedAgain_ThenOnlyOneRequestIsSent',
    () async {
      // Given
      final pending = Completer<Result<void>>();
      when(
        () => repository.resendVerificationEmail(),
      ).thenAnswer((_) => pending.future);
      final controller = controllerUnderTest();

      // When
      final first = controller.resend();
      final second = controller.resend();
      pending.complete(const Success<void>(null));
      await Future.wait<void>(<Future<void>>[first, second]);

      // Then
      verify(() => repository.resendVerificationEmail()).called(1);
    },
  );

  // The two halves are independent: a resend after a refused token must not
  // overwrite what the verification said.
  test('GivenRejectedToken_WhenResent_ThenTheRejectionIsKept', () async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.validation, errors: <String>['No good.']),
      ),
    );
    answerResendWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.verify('stale');

    // When
    await controller.resend();

    // Then
    expect(currentState().verification, isA<VerifyRejected>());
    expect(currentState().resend, isA<ResendSent>());
  });
}
