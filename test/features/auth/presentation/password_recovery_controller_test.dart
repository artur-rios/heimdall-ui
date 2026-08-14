import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/password_recovery_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;

  PasswordRecoveryController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(passwordRecoveryControllerProvider.notifier);
  }

  void answerWith(Result<void> result) {
    when(
      () => repository.requestPasswordRecovery(email: any(named: 'email')),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockAuthRepository();
  });

  test('GivenAcceptedRequest_WhenRecoveryRequested_ThenStateIsSent', () async {
    // Given
    answerWith(const Success<void>(null));
    final controller = controllerUnderTest();

    // When
    await controller.request('a@b.c');

    // Then
    expect(
      container.read(passwordRecoveryControllerProvider),
      isA<RecoverySent>(),
    );
  });

  test(
    'GivenAnyAddress_WhenRecoveryRequested_ThenTheAddressIsSentAsTyped',
    () async {
      // Given
      answerWith(const Success<void>(null));
      final controller = controllerUnderTest();

      // When
      await controller.request('a@b.c');

      // Then
      verify(
        () => repository.requestPasswordRecovery(email: 'a@b.c'),
      ).called(1);
    },
  );

  // The neutral confirmation: an unregistered address is answered by the API
  // exactly as a registered one is, and reaches the same state here.
  test('GivenUnknownAddress_WhenRecoveryRequested_ThenStateIsSent', () async {
    // Given
    answerWith(const Success<void>(null));
    final controller = controllerUnderTest();

    // When
    await controller.request('nobody@nowhere.invalid');

    // Then
    expect(
      container.read(passwordRecoveryControllerProvider),
      isA<RecoverySent>(),
    );
  });

  // AF-03b — a transport failure never becomes a confirmation.
  test(
    'GivenTransportFailure_WhenRecoveryRequested_ThenStateIsFailed',
    () async {
      // Given
      answerWith(
        const FailureResult<void>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      final controller = controllerUnderTest();

      // When
      await controller.request('a@b.c');

      // Then
      final state = container.read(passwordRecoveryControllerProvider);
      expect(state, isA<RecoveryFailed>());
      expect((state as RecoveryFailed).failure.kind, FailureKind.network);
    },
  );

  test(
    'GivenRejectedRequest_WhenRecoveryRequested_ThenApiErrorsAreKept',
    () async {
      // Given
      answerWith(
        const FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: <String>['Email is required.'],
          ),
        ),
      );
      final controller = controllerUnderTest();

      // When
      await controller.request('not-an-address');

      // Then
      final state = container.read(passwordRecoveryControllerProvider);
      expect((state as RecoveryFailed).failure.errors, <String>[
        'Email is required.',
      ]);
    },
  );

  // AF-03c — a second request while the first is in flight is not sent.
  test(
    'GivenRequestInFlight_WhenRequestedAgain_ThenOnlyOneRequestIsSent',
    () async {
      // Given
      final pending = Completer<Result<void>>();
      when(
        () => repository.requestPasswordRecovery(email: any(named: 'email')),
      ).thenAnswer((_) => pending.future);
      final controller = controllerUnderTest();

      // When
      final first = controller.request('a@b.c');
      final second = controller.request('a@b.c');
      pending.complete(const Success<void>(null));
      await Future.wait<void>(<Future<void>>[first, second]);

      // Then
      verify(
        () => repository.requestPasswordRecovery(email: 'a@b.c'),
      ).called(1);
    },
  );

  test('GivenFailedRequest_WhenReset_ThenStateIsIdle', () async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();
    await controller.request('a@b.c');

    // When
    controller.reset();

    // Then
    expect(
      container.read(passwordRecoveryControllerProvider),
      isA<RecoveryIdle>(),
    );
  });
}
