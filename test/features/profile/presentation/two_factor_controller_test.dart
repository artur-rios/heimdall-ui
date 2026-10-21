import 'dart:async';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/core/unload/unload_guard.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/domain/two_factor.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/two_factor_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/idle_expiry_timer.dart';
import '../../../support/late_answer.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Records what the controller asked of the browser's leave confirmation.
class _FakeUnloadGuard implements UnloadGuard {
  final List<String> calls = <String>[];

  @override
  void register() => calls.add('register');

  @override
  void unregister() => calls.add('unregister');
}

String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'email': 'ada@example.com',
        'role': 3,
      }),
    ),
  );

  return 'header.$payload.signature';
}

/// The API's answer to a wrong password (TwoFactorMessages.PasswordMismatch).
const _wrongPassword = Failure(
  kind: FailureKind.validation,
  errors: <String>['The current password is incorrect.'],
);

const _off = TwoFactorStatus();
const _on = TwoFactorStatus(
  isActive: true,
  appEnabled: true,
  remainingRecoveryCodes: 8,
);

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;
  late _FakeUnloadGuard guard;
  late ProviderContainer container;

  TwoFactorController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
        sessionExpiryTimerProvider.overrideWithValue(idleExpiryTimer),
        unloadGuardProvider.overrideWithValue(guard),
      ],
    );
    addTearDown(container.dispose);

    return container.read(twoFactorControllerProvider.notifier);
  }

  TwoFactorState currentState() => container.read(twoFactorControllerProvider);

  SessionState session() => container.read(sessionControllerProvider);

  /// A person signed in, so a test can see whether the session survives.
  Future<TwoFactorController> signedInControllerUnderTest() async {
    await store.write(AuthToken(value: _jwt(), expiresAt: DateTime.utc(2030)));
    final controller = controllerUnderTest();
    await container.read(sessionControllerProvider.notifier).restore();

    return controller;
  }

  void answerStatusWith(Result<TwoFactorStatus> result) {
    when(() => repository.twoFactorStatus()).thenAnswer((_) async => result);
  }

  void answerEnableWith(Result<TwoFactorSetup> result) {
    when(
      () => repository.enableTwoFactor(
        any(),
        currentPassword: any(named: 'currentPassword'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerConfirmWith(Result<List<String>> result) {
    when(
      () => repository.confirmTwoFactor(
        method: any(named: 'method'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerDisableWith(Result<void> result) {
    when(
      () => repository.disableTwoFactor(
        password: any(named: 'password'),
        code: any(named: 'code'),
        recoveryCode: any(named: 'recoveryCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerRegenerateWith(Result<List<String>> result) {
    when(
      () => repository.regenerateRecoveryCodes(
        code: any(named: 'code'),
        recoveryCode: any(named: 'recoveryCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUpAll(() => registerFallbackValue(TwoFactorMethod.app));

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
    guard = _FakeUnloadGuard();
  });

  test('GivenAConfiguration_WhenLoaded_ThenItIsShown', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as TwoFactorSettled).status.isActive, isTrue);
  });

  // A Google User may never configure this, which is permanent.
  test('GivenAGoogleUser_WhenLoaded_ThenTheyAreIneligible', () async {
    // Given
    answerStatusWith(
      const FailureResult<TwoFactorStatus>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as TwoFactorUnavailable).ineligible, isTrue);
  });

  test('GivenATransportFailure_WhenLoaded_ThenItIsNotIneligibility', () async {
    // Given
    answerStatusWith(
      const FailureResult<TwoFactorStatus>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as TwoFactorUnavailable).ineligible, isFalse);
  });

  test('GivenTheAppMethod_WhenStarted_ThenConfirmationIsAwaited', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(
          method: TwoFactorMethod.app,
          otpAuthUri: 'otpauth://totp/x?secret=A',
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.beginSetup(TwoFactorMethod.app, currentPassword: 'secret');

    // Then
    final state = currentState() as TwoFactorConfirming;
    expect(state.setup.method, TwoFactorMethod.app);
  });

  // AF-09b — leaving before confirming keeps the feature off and drops the
  // pending secret.
  test('GivenAPendingSetup_WhenAbandoned_ThenTheSecretIsDropped', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(
          method: TwoFactorMethod.app,
          otpAuthUri: 'otpauth://totp/x?secret=A',
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    await controller.beginSetup(TwoFactorMethod.app, currentPassword: 'secret');

    // When
    controller.abandonSetup();

    // Then
    final state = currentState() as TwoFactorSettled;
    expect(state.status.isActive, isFalse);
  });

  test('GivenAConfirmedSetup_WhenConfirmed_ThenTheCodesAreIssued', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.email, emailCodeSent: true),
      ),
    );
    answerConfirmWith(const Success<List<String>>(<String>['aaa', 'bbb']));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.beginSetup(
      TwoFactorMethod.email,
      currentPassword: 'secret',
    );

    // When
    await controller.confirm('123456');

    // Then
    expect((currentState() as TwoFactorCodesIssued).codes, <String>[
      'aaa',
      'bbb',
    ]);
  });

  // AF-09a — a rejected code keeps the setup alive rather than restarting it.
  test('GivenAWrongCode_WhenConfirmed_ThenTheSetupSurvives', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.app, otpAuthUri: 'otpauth://x'),
      ),
    );
    answerConfirmWith(
      const FailureResult<List<String>>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That code is not correct.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    await controller.beginSetup(TwoFactorMethod.app, currentPassword: 'secret');

    // When
    await controller.confirm('000000');

    // Then
    final state = currentState() as TwoFactorConfirming;
    expect(state.failure?.errors, <String>['That code is not correct.']);
    expect(state.busy, isFalse);
  });

  // FR-AU-28 — confirming revokes the token that confirmed, so asking the API
  // anything more under it would only end the session before the codes are
  // seen. The status follows from the command instead.
  test('GivenAConfirmedSetup_WhenConfirmed_ThenTheStatusIsNotReread', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.app, otpAuthUri: 'otpauth://x'),
      ),
    );
    answerConfirmWith(const Success<List<String>>(<String>['aaa', 'bbb']));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.beginSetup(TwoFactorMethod.app, currentPassword: 'secret');

    // When
    await controller.confirm('123456');

    // Then
    verify(() => repository.twoFactorStatus()).called(1);
    final status = (currentState() as TwoFactorCodesIssued).status;
    expect(status.isActive, isTrue);
    expect(status.methods, <TwoFactorMethod>[TwoFactorMethod.app]);
    expect(status.remainingRecoveryCodes, 2);
  });

  // The codes come first: the session holds until they are acknowledged.
  test('GivenAConfirmedSetup_WhenConfirmed_ThenTheSessionStays', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.email, emailCodeSent: true),
      ),
    );
    answerConfirmWith(const Success<List<String>>(<String>['aaa']));
    final controller = await signedInControllerUnderTest();
    await controller.load();
    await controller.beginSetup(
      TwoFactorMethod.email,
      currentPassword: 'secret',
    );

    // When
    await controller.confirm('123456');

    // Then
    expect(currentState(), isA<TwoFactorCodesIssued>());
    expect(session(), isA<Authenticated>());
  });

  // FR-AU-28 — once the codes are acknowledged, the revoked token is let go
  // and the person signs in again, now with their second factor.
  test('GivenConfirmedCodes_WhenAcknowledged_ThenTheSessionEnds', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.app, otpAuthUri: 'otpauth://x'),
      ),
    );
    answerConfirmWith(const Success<List<String>>(<String>['aaa']));
    final controller = await signedInControllerUnderTest();
    await controller.load();
    await controller.beginSetup(TwoFactorMethod.app, currentPassword: 'secret');
    await controller.confirm('123456');

    // When
    await controller.acknowledgeCodes();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    expect(await store.read(), isNull);
  });

  test('GivenRegeneratedCodes_WhenAcknowledged_ThenTheSessionEnds', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerRegenerateWith(const Success<List<String>>(<String>['xxx']));
    final controller = await signedInControllerUnderTest();
    await controller.load();
    await controller.regenerateRecoveryCodes(code: '123456');

    // When
    await controller.acknowledgeCodes();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
  });

  test('GivenRegeneratedCodes_WhenIssued_ThenTheStatusIsNotReread', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerRegenerateWith(
      const Success<List<String>>(<String>['xxx', 'yyy', 'zzz']),
    );
    final controller = await signedInControllerUnderTest();
    await controller.load();

    // When
    await controller.regenerateRecoveryCodes(code: '123456');

    // Then
    verify(() => repository.twoFactorStatus()).called(1);
    final status = (currentState() as TwoFactorCodesIssued).status;
    expect(status.remainingRecoveryCodes, 3);
    expect(session(), isA<Authenticated>());
  });

  // FR-AU-17 — starting a setup asks for the current password.
  test('GivenAPassword_WhenStarted_ThenItIsSent', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.app, otpAuthUri: 'otpauth://x'),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.beginSetup(TwoFactorMethod.app, currentPassword: 'pw');

    // Then
    verify(
      () => repository.enableTwoFactor(
        TwoFactorMethod.app,
        currentPassword: 'pw',
      ),
    ).called(1);
  });

  // AF-09f — a wrong password is shown, the feature stays off, and the
  // person stays signed in to correct it.
  // The refusal goes back to the password dialog, which stays open to show
  // it; the section stays as it was, with nothing of its own to show.
  test('GivenAWrongPassword_WhenStarted_ThenTheRefusalIsReturned', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(const FailureResult<TwoFactorSetup>(_wrongPassword));
    final controller = await signedInControllerUnderTest();
    await controller.load();

    // When
    final failure = await controller.beginSetup(
      TwoFactorMethod.app,
      currentPassword: 'x',
    );

    // Then
    expect(failure?.errors, <String>['The current password is incorrect.']);
    final state = currentState() as TwoFactorSettled;
    expect(state.failure, isNull);
    expect(state.busy, isFalse);
    expect(state.status.isActive, isFalse);
    expect(session(), isA<Authenticated>());
  });

  test('GivenAPassword_WhenTheSetupStarts_ThenNoRefusalIsReturned', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.app, otpAuthUri: 'otpauth://x'),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final failure = await controller.beginSetup(
      TwoFactorMethod.app,
      currentPassword: 'secret',
    );

    // Then
    expect(failure, isNull);
    expect(currentState(), isA<TwoFactorConfirming>());
  });

  // AF-09c — closing or reloading the tab asks first while codes wait.
  test('GivenIssuedCodes_WhenShown_ThenTheUnloadGuardIsRegistered', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerRegenerateWith(const Success<List<String>>(<String>['xxx']));
    final controller = await signedInControllerUnderTest();
    await controller.load();

    // When
    await controller.regenerateRecoveryCodes(code: '123456');

    // Then
    expect(guard.calls, <String>['register']);
  });

  test(
    'GivenIssuedCodes_WhenAcknowledged_ThenTheUnloadGuardIsUnregistered',
    () async {
      // Given
      answerStatusWith(const Success<TwoFactorStatus>(_on));
      answerRegenerateWith(const Success<List<String>>(<String>['xxx']));
      final controller = await signedInControllerUnderTest();
      await controller.load();
      await controller.regenerateRecoveryCodes(code: '123456');

      // When
      await controller.acknowledgeCodes();

      // Then
      expect(guard.calls, <String>['register', 'unregister']);
    },
  );

  // The session ending drops the codes with it, and their guard too.
  test(
    'GivenIssuedCodes_WhenTheControllerIsDropped_ThenTheGuardIsUnregistered',
    () async {
      // Given
      answerStatusWith(const Success<TwoFactorStatus>(_on));
      answerRegenerateWith(const Success<List<String>>(<String>['xxx']));
      final controller = await signedInControllerUnderTest();
      await controller.load();
      await controller.regenerateRecoveryCodes(code: '123456');

      // When
      container.invalidate(twoFactorControllerProvider);
      container.read(twoFactorControllerProvider);

      // Then
      expect(guard.calls, <String>['register', 'unregister']);
    },
  );

  test('GivenNoCodes_WhenTheSectionLoads_ThenNoGuardIsRegistered', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(guard.calls, isEmpty);
  });

  // AF-09c — the codes are shown once, and acknowledging them is what moves
  // the screen on.
  test('GivenIssuedCodes_WhenAcknowledged_ThenTheSectionSettles', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerRegenerateWith(const Success<List<String>>(<String>['xxx']));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.regenerateRecoveryCodes(code: '123456');

    // When
    await controller.acknowledgeCodes();

    // Then
    expect(currentState(), isA<TwoFactorSettled>());
  });

  test(
    'GivenRegeneratedCodes_WhenIssued_ThenTheyAreMarkedAsReplacing',
    () async {
      // Given
      answerStatusWith(const Success<TwoFactorStatus>(_on));
      answerRegenerateWith(const Success<List<String>>(<String>['xxx']));
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.regenerateRecoveryCodes(code: '123456');

      // Then
      expect((currentState() as TwoFactorCodesIssued).regenerated, isTrue);
    },
  );

  test('GivenACredential_WhenDisabled_ThenItIsSent', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerDisableWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.disable(password: 'secret');

    // Then
    verify(
      () => repository.disableTwoFactor(
        password: 'secret',
        code: null,
        recoveryCode: null,
      ),
    ).called(1);
  });

  // AF-09d — the API rejected the credential, and the feature stays on.
  test('GivenARejectedCredential_WhenDisabled_ThenTheFeatureStaysOn', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerDisableWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That password is not correct.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.disable(password: 'wrong');

    // Then
    final state = currentState() as TwoFactorSettled;
    expect(state.status.isActive, isTrue);
    expect(state.failure?.errors, <String>['That password is not correct.']);
  });

  // FR-AU-28 — turning it off revokes the token, so the person signs in
  // again straight away, and nothing more is asked under the old token.
  test('GivenACredential_WhenDisabled_ThenTheSessionEnds', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerDisableWith(const Success<void>(null));
    final controller = await signedInControllerUnderTest();
    await controller.load();

    // When
    await controller.disable(password: 'secret', code: '123456');

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    verify(() => repository.twoFactorStatus()).called(1);
  });

  test('GivenARejectedCredential_WhenDisabled_ThenTheSessionStays', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerDisableWith(const FailureResult<void>(_wrongPassword));
    final controller = await signedInControllerUnderTest();
    await controller.load();

    // When
    await controller.disable(password: 'wrong', code: '123456');

    // Then
    expect(session(), isA<Authenticated>());
  });

  test('GivenACommandInFlight_WhenAskedAgain_ThenOnlyOneIsSent', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerDisableWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await Future.wait<void>(<Future<void>>[
      controller.disable(password: 'secret'),
      controller.disable(password: 'secret'),
    ]);

    // Then
    verify(
      () => repository.disableTwoFactor(
        password: any(named: 'password'),
        code: any(named: 'code'),
        recoveryCode: any(named: 'recoveryCode'),
      ),
    ).called(1);
  });

  // A sign-out resets the screen while its read is in flight, and the late
  // answer must not land in the reset state.
  test(
    'GivenALoadInFlight_WhenTheSessionResets_ThenTheAnswerIsDropped',
    () async {
      // Given
      final answer = Completer<Result<TwoFactorStatus>>();
      when(() => repository.twoFactorStatus()).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();

      // When
      await answerAfterReset(
        container,
        twoFactorControllerProvider,
        reset: twoFactorControllerProvider,
        start: controller.load,
        answer: () => answer.complete(const Success<TwoFactorStatus>(_on)),
      );

      // Then
      expect(currentState(), isA<TwoFactorLoading>());
    },
  );

  // Recovery codes issued to a session that has since ended are never shown
  // in the state the next session starts from.
  test(
    'GivenAConfirmInFlight_WhenTheSessionResets_ThenNoCodesAreKept',
    () async {
      // Given
      answerStatusWith(const Success<TwoFactorStatus>(_off));
      answerEnableWith(
        const Success<TwoFactorSetup>(
          TwoFactorSetup(
            method: TwoFactorMethod.app,
            otpAuthUri: 'otpauth://totp/x?secret=A',
          ),
        ),
      );
      final answer = Completer<Result<List<String>>>();
      when(
        () => repository.confirmTwoFactor(
          method: any(named: 'method'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) => answer.future);
      final controller = controllerUnderTest();
      await controller.load();
      await controller.beginSetup(
        TwoFactorMethod.app,
        currentPassword: 'secret',
      );

      // When
      await answerAfterReset(
        container,
        twoFactorControllerProvider,
        reset: twoFactorControllerProvider,
        start: () => controller.confirm('123456'),
        answer: () => answer.complete(
          const Success<List<String>>(<String>['code-1', 'code-2']),
        ),
      );

      // Then
      expect(currentState(), isA<TwoFactorLoading>());
      expect(guard.calls, isNot(contains('register')));
    },
  );
}
