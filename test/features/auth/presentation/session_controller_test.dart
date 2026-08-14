import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// A token whose payload claims the System Admin role, so the principal read
/// from it is something the guards can be asserted against.
const String _systemAdminJwt =
    'header.'
    'eyJzdWIiOiI2ZjFkM2EwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDEiLCJlbWFpbCI6'
    'ImFkbWluQGV4YW1wbGUuY29tIiwicm9sZSI6MX0.'
    'signature';

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;

  AuthToken tokenFor(String value) =>
      AuthToken(value: value, expiresAt: DateTime.utc(2030));

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  /// A container whose session already holds a challenge, which is where every
  /// UI-02 flow starts.
  Future<ProviderContainer> challengedContainer({
    List<String> methods = const <String>['Totp'],
  }) async {
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(
        TwoFactorRequired(
          challengeToken: 'challenge',
          availableMethods: methods,
        ),
      ),
    );
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    // Settle the start-up read first, so it cannot land on the challenge.
    await controller.restore();
    await controller.signIn(email: 'a@b.c', password: 'secret');

    return container;
  }

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
  });

  test(
    'GivenValidCredentials_WhenSignedIn_ThenSessionIsAuthenticated',
    () async {
      // Given
      when(
        () => repository.login(email: 'a@b.c', password: 'secret'),
      ).thenAnswer(
        (_) async => Success<LoginOutcome>(LoggedIn(tokenFor(_systemAdminJwt))),
      );
      final container = containerWith();

      // When
      await container
          .read(sessionControllerProvider.notifier)
          .signIn(email: 'a@b.c', password: 'secret');

      // Then
      final state = container.read(sessionControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).principal.role, Role.systemAdmin);
      expect((await store.read())?.value, _systemAdminJwt);
    },
  );

  test('GivenTwoFactorRequired_WhenSignedIn_ThenSessionIsChallenged', () async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => const Success<LoginOutcome>(
        TwoFactorRequired(
          challengeToken: 'challenge',
          availableMethods: <String>['Totp'],
        ),
      ),
    );
    final container = containerWith();

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'a@b.c', password: 'secret');

    // Then
    final state = container.read(sessionControllerProvider);
    expect(state, isA<Challenged>());
    expect((state as Challenged).challengeToken, 'challenge');
    expect(await store.read(), isNull);
  });

  // AF-01d — the API could not be reached; nothing about the session changes.
  test(
    'GivenTransportFailure_WhenSignedIn_ThenNetworkFailureIsReturned',
    () async {
      // Given
      when(
        () => repository.login(email: 'a@b.c', password: 'secret'),
      ).thenAnswer(
        (_) async => const FailureResult<LoginOutcome>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      final container = containerWith();

      // When
      final result = await container
          .read(sessionControllerProvider.notifier)
          .signIn(email: 'a@b.c', password: 'secret');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
      expect(await store.read(), isNull);
    },
  );

  test(
    'GivenChallengedSession_WhenCodeAccepted_ThenSessionIsAuthenticated',
    () async {
      // Given
      when(
        () => repository.login(email: 'a@b.c', password: 'secret'),
      ).thenAnswer(
        (_) async => const Success<LoginOutcome>(
          TwoFactorRequired(
            challengeToken: 'challenge',
            availableMethods: <String>['Totp'],
          ),
        ),
      );
      when(
        () => repository.verifySecondFactor(
          challengeToken: 'challenge',
          code: '123456',
          isRecoveryCode: false,
        ),
      ).thenAnswer((_) async => Success<AuthToken>(tokenFor(_systemAdminJwt)));
      final container = containerWith();
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.signIn(email: 'a@b.c', password: 'secret');

      // When
      await controller.submitSecondFactor('123456');

      // Then
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  test(
    'GivenNoChallengeInProgress_WhenSecondFactorSubmitted_ThenItIsRejected',
    () async {
      // Given
      final container = containerWith();
      final controller = container.read(sessionControllerProvider.notifier);
      await container.read(sessionControllerProvider.notifier).signOut();

      // When
      final result = await controller.submitSecondFactor('123456');

      // Then
      expect(result.isSuccess, isFalse);
      verifyNever(
        () => repository.verifySecondFactor(
          challengeToken: any(named: 'challengeToken'),
          code: any(named: 'code'),
          isRecoveryCode: any(named: 'isRecoveryCode'),
        ),
      );
    },
  );

  test(
    'GivenInvalidCredentials_WhenSignedIn_ThenSessionStaysUnauthenticated',
    () async {
      // Given
      when(
        () => repository.login(email: 'a@b.c', password: 'wrong'),
      ).thenAnswer(
        (_) async => const FailureResult<LoginOutcome>(
          Failure(
            kind: FailureKind.validation,
            errors: <String>['Invalid credentials'],
          ),
        ),
      );
      final container = containerWith();

      // When
      final result = await container
          .read(sessionControllerProvider.notifier)
          .signIn(email: 'a@b.c', password: 'wrong');

      // Then
      expect(result.isSuccess, isFalse);
      expect(result.failureOrNull?.errors, <String>['Invalid credentials']);
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    },
  );

  test('GivenAuthenticatedSession_WhenSignedOut_ThenTokenIsCleared', () async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(LoggedIn(tokenFor(_systemAdminJwt))),
    );
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.signIn(email: 'a@b.c', password: 'secret');

    // When
    await controller.signOut();

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    expect(await store.read(), isNull);
  });

  test(
    'GivenStoredValidToken_WhenRestored_ThenSessionIsAuthenticated',
    () async {
      // Given
      await store.write(tokenFor(_systemAdminJwt));
      final container = containerWith();

      // When
      await container.read(sessionControllerProvider.notifier).restore();

      // Then
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  test('GivenStoredExpiredToken_WhenRestored_ThenItIsDiscarded', () async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2000)),
    );
    final container = containerWith();

    // When
    await container.read(sessionControllerProvider.notifier).restore();

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    expect(await store.read(), isNull);
  });

  // AF-02a — a wrong code is the user's problem to fix, not the challenge's end.
  test('GivenWrongCode_WhenSubmitted_ThenTheChallengeSurvives', () async {
    // Given
    final container = await challengedContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    when(
      () => repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: '000000',
        isRecoveryCode: false,
      ),
    ).thenAnswer(
      (_) async => const FailureResult<AuthToken>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The code is incorrect.'],
        ),
      ),
    );

    // When
    final result = await controller.submitSecondFactor('000000');

    // Then
    expect(result.failureOrNull?.errors, <String>['The code is incorrect.']);
    expect(container.read(sessionControllerProvider), isA<Challenged>());
  });

  // AF-02b — a challenge the API will not accept again cannot be retried.
  test(
    'GivenExpiredChallenge_WhenSubmitted_ThenTheChallengeIsDiscarded',
    () async {
      // Given
      final container = await challengedContainer();
      final controller = container.read(sessionControllerProvider.notifier);
      when(
        () => repository.verifySecondFactor(
          challengeToken: 'challenge',
          code: '123456',
          isRecoveryCode: false,
        ),
      ).thenAnswer(
        (_) async => const FailureResult<AuthToken>(
          Failure(
            kind: FailureKind.unauthorized,
            errors: <String>['The challenge has expired.'],
          ),
        ),
      );

      // When
      await controller.submitSecondFactor('123456');

      // Then
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    },
  );

  // AF-02c — the choice belongs to the challenge, so it outlives a rebuild.
  test('GivenSeveralMethods_WhenOneIsChosen_ThenItIsRemembered', () async {
    // Given
    final container = await challengedContainer(
      methods: const <String>['Totp', 'Email'],
    );

    // When
    container.read(sessionControllerProvider.notifier).chooseMethod('Email');

    // Then
    final state = container.read(sessionControllerProvider) as Challenged;
    expect(state.methodInUse, 'Email');
  });

  // AF-02c — the API decides what is on offer; nothing else may be selected.
  test('GivenUnofferedMethod_WhenChosen_ThenTheChoiceIsIgnored', () async {
    // Given
    final container = await challengedContainer();

    // When
    container.read(sessionControllerProvider.notifier).chooseMethod('Carrier');

    // Then
    final state = container.read(sessionControllerProvider) as Challenged;
    expect(state.methodInUse, 'Totp');
  });

  // AF-02d — the recovery code is flagged so it reaches the right API field.
  test('GivenRecoveryCode_WhenSubmitted_ThenItIsSentAsOne', () async {
    // Given
    final container = await challengedContainer();
    final controller = container.read(sessionControllerProvider.notifier);
    when(
      () => repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: 'recovery-code',
        isRecoveryCode: true,
      ),
    ).thenAnswer((_) async => Success<AuthToken>(tokenFor(_systemAdminJwt)));

    // When
    await controller.submitSecondFactor('recovery-code', isRecoveryCode: true);

    // Then
    verify(
      () => repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: 'recovery-code',
        isRecoveryCode: true,
      ),
    ).called(1);
  });

  // AF-02e — leaving ends the challenge, and it was never persisted.
  test(
    'GivenChallengedSession_WhenAbandoned_ThenSessionIsUnauthenticated',
    () async {
      // Given
      final container = await challengedContainer();

      // When
      container.read(sessionControllerProvider.notifier).abandonChallenge();

      // Then
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
      expect(await store.read(), isNull);
    },
  );

  // AF-02e — abandoning is only ever about a challenge; a real session stands.
  test(
    'GivenAuthenticatedSession_WhenAbandonCalled_ThenSessionStands',
    () async {
      // Given
      when(
        () => repository.login(email: 'a@b.c', password: 'secret'),
      ).thenAnswer(
        (_) async => Success<LoginOutcome>(LoggedIn(tokenFor(_systemAdminJwt))),
      );
      final container = containerWith();
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.signIn(email: 'a@b.c', password: 'secret');

      // When
      controller.abandonChallenge();

      // Then
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  test('GivenMalformedToken_WhenPrincipalRead_ThenRoleFallsBackToUser', () {
    // Given
    final token = AuthToken(value: 'not-a-jwt', expiresAt: DateTime.utc(2030));

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.role, Role.user);
    expect(principal.id, isEmpty);
  });
}
