import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/two_factor.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/two_factor_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _off = TwoFactorStatus();
const _on = TwoFactorStatus(
  isActive: true,
  appEnabled: true,
  remainingRecoveryCodes: 8,
);

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;

  TwoFactorController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(twoFactorControllerProvider.notifier);
  }

  TwoFactorState currentState() => container.read(twoFactorControllerProvider);

  void answerStatusWith(Result<TwoFactorStatus> result) {
    when(() => repository.twoFactorStatus()).thenAnswer((_) async => result);
  }

  void answerEnableWith(Result<TwoFactorSetup> result) {
    when(
      () => repository.enableTwoFactor(any()),
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
    await controller.beginSetup(TwoFactorMethod.app);

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
    await controller.beginSetup(TwoFactorMethod.app);

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
    await controller.beginSetup(TwoFactorMethod.email);

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
    await controller.beginSetup(TwoFactorMethod.app);

    // When
    await controller.confirm('000000');

    // Then
    final state = currentState() as TwoFactorConfirming;
    expect(state.failure?.errors, <String>['That code is not correct.']);
    expect(state.busy, isFalse);
  });

  test('GivenAConfirmedSetup_WhenConfirmed_ThenTheStatusIsReread', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.app, otpAuthUri: 'otpauth://x'),
      ),
    );
    answerConfirmWith(const Success<List<String>>(<String>['aaa']));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.beginSetup(TwoFactorMethod.app);

    // When
    await controller.confirm('123456');

    // Then
    verify(() => repository.twoFactorStatus()).called(2);
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
    controller.acknowledgeCodes();

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

  // A command that worked should not drop the screen into an error because the
  // re-read afterwards failed.
  test('GivenAFailedReread_WhenDisabled_ThenTheCommandStillCounts', () async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerDisableWith(const Success<void>(null));
    final controller = controllerUnderTest();
    await controller.load();
    answerStatusWith(
      const FailureResult<TwoFactorStatus>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await controller.disable(password: 'secret');

    // Then
    expect(currentState(), isA<TwoFactorSettled>());
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
}
