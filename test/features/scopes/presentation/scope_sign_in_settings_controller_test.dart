import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_sign_in_settings_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  selfRegistrationEnabled: true,
  defaultLegalBasis: 2,
  privacyNoticeUri: 'https://acme.example/privacy',
  emailVerificationUrl: 'https://acme.example/verify-email',
);

/// What the Google Sign-In endpoint answers: no self-registration, no privacy.
const _toggledOn = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  emailVerificationUrl: 'https://acme.example/verify-email',
);

const _deleted = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  isDeleted: true,
);

const _refused = Failure(
  kind: FailureKind.forbidden,
  errors: <String>['You do not own this scope.'],
);

void main() {
  late _MockScopeRepository repository;
  late ProviderContainer container;

  ScopeSignInSettingsController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(
      scopeSignInSettingsControllerProvider('scope-1').notifier,
    );
  }

  SignInSettingsState currentState() =>
      container.read(scopeSignInSettingsControllerProvider('scope-1'));

  SignInSettingsLoaded loaded() => currentState() as SignInSettingsLoaded;

  void answerGetWith(Result<Scope> result) {
    when(
      () => repository.getById(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerGoogleWith(Result<Scope> result) {
    when(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerSignUpWith(Result<Scope> result) {
    when(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerLinksWith(Result<Scope> result) {
    when(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopeRepository();
  });

  test('GivenAScope_WhenLoaded_ThenItsSettingsAreShown', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(loaded().scope.selfRegistrationEnabled, isTrue);
  });

  // AF-31a
  test('GivenAMissingScope_WhenLoaded_ThenStateIsNotFound', () async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as SignInSettingsUnavailable).isNotFound, isTrue);
  });

  // AF-31b
  test('GivenADeletedScope_WhenLoaded_ThenItIsReadOnly', () async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(loaded().isReadOnly, isTrue);
  });

  test('GivenADeletedScope_WhenSignUpOpened_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setSelfRegistration(true);

    // Then
    verifyNever(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  test('GivenGoogleOff_WhenTurnedOn_ThenSignUpAndPrivacyAreKept', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_toggledOn));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setGoogleSignIn(true);

    // Then
    final scope = loaded().scope;
    expect(scope.googleSignInEnabled, isTrue);
    expect(scope.selfRegistrationEnabled, isTrue);
    expect(scope.defaultLegalBasis, 2);
    expect(scope.privacyNoticeUri, 'https://acme.example/privacy');
  });

  test(
    'GivenSignUpOn_WhenClosed_ThenTheApiIsAskedAndTheStateSettles',
    () async {
      // Given
      answerGetWith(const Success<Scope>(_acme));
      answerSignUpWith(
        const Success<Scope>(
          Scope(id: 'scope-1', name: 'Acme', description: 'The first tenant'),
        ),
      );
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.setSelfRegistration(false);

      // Then
      verify(
        () => repository.setSelfRegistration(id: 'scope-1', enabled: false),
      ).called(1);
      expect(loaded().scope.selfRegistrationEnabled, isFalse);
      expect(loaded().scope.privacyNoticeUri, 'https://acme.example/privacy');
      expect(loaded().isBusy, isFalse);
    },
  );

  // AF-31c
  test(
    'GivenARefusedSignUpToggle_WhenAttempted_ThenTheStateIsUnchanged',
    () async {
      // Given
      answerGetWith(const Success<Scope>(_acme));
      answerSignUpWith(const FailureResult<Scope>(_refused));
      final controller = controllerUnderTest();
      await controller.load();

      // When
      await controller.setSelfRegistration(false);

      // Then
      expect(loaded().scope.selfRegistrationEnabled, isTrue);
      expect(loaded().selfRegistrationFailure, same(_refused));
    },
  );

  test('GivenARequestInFlight_WhenAnotherIsAsked_ThenOnlyOneIsSent', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final pending = Completer<Result<Scope>>();
    when(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final first = controller.setSelfRegistration(false);
    await controller.setGoogleSignIn(true);
    pending.complete(const Success<Scope>(_acme));
    await first;

    // Then
    verifyNever(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  test('GivenChangedLinks_WhenSaved_ThenBothAreSentTrimmed', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: '  https://acme.example/verify-email  ',
      passwordResetUrl: ' https://acme.example/password-reset ',
    );

    // Then
    verify(
      () => repository.setEmailLinks(
        id: 'scope-1',
        emailVerificationUrl: 'https://acme.example/verify-email',
        passwordResetUrl: 'https://acme.example/password-reset',
      ),
    ).called(1);
    expect(loaded().linksSaved, isTrue);
  });

  test('GivenAnEmptiedLink_WhenSaved_ThenItIsSentAsNull', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: '   ',
      passwordResetUrl: null,
    );

    // Then
    verify(
      () => repository.setEmailLinks(
        id: 'scope-1',
        emailVerificationUrl: null,
        passwordResetUrl: null,
      ),
    ).called(1);
  });

  test('GivenUnchangedLinks_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: ' https://acme.example/verify-email ',
      passwordResetUrl: '   ',
    );

    // Then
    verifyNever(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    );
  });

  // AF-31d
  test('GivenRefusedLinks_WhenSaved_ThenApiErrorsAreKept', () async {
    // Given
    const refusal = Failure(
      kind: FailureKind.validation,
      errors: <String>['The email link must be an absolute URL.'],
    );
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const FailureResult<Scope>(refusal));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: 'https://other.example/verify',
      passwordResetUrl: null,
    );

    // Then
    expect(loaded().linksFailure, same(refusal));
    expect(
      loaded().scope.emailVerificationUrl,
      'https://acme.example/verify-email',
    );
    expect(loaded().linksSaved, isFalse);
  });

  test(
    'GivenAStaleLinksFailure_WhenLinksAreBackToSaved_ThenItClears',
    () async {
      // Given
      answerGetWith(const Success<Scope>(_acme));
      answerLinksWith(
        const FailureResult<Scope>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      final controller = controllerUnderTest();
      await controller.load();
      await controller.saveEmailLinks(
        emailVerificationUrl: 'https://other.example/verify',
        passwordResetUrl: null,
      );
      expect(loaded().linksFailure, isNotNull);

      // When
      await controller.saveEmailLinks(
        emailVerificationUrl: 'https://acme.example/verify-email',
        passwordResetUrl: null,
      );

      // Then
      expect(loaded().linksFailure, isNull);
      expect(loaded().linksSaved, isFalse);
    },
  );

  test('GivenSavedLinks_WhenAcknowledged_ThenTheNoticeClears', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.saveEmailLinks(
      emailVerificationUrl: null,
      passwordResetUrl: null,
    );

    // When
    controller.acknowledgeLinks();

    // Then
    expect(loaded().linksSaved, isFalse);
    expect(loaded().linksFailure, isNull);
  });
}
