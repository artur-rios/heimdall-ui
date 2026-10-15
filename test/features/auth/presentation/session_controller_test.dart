import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// A store the platform cannot use — a locked keyring, a key lost to a backup
/// restore.
class _BrokenTokenStore implements TokenStore {
  @override
  Future<AuthToken?> read() async => throw StateError('keyring locked');

  @override
  Future<void> write(AuthToken token) async =>
      throw StateError('keyring locked');

  @override
  Future<void> clear() async => throw StateError('keyring locked');
}

/// A JWT shaped exactly as the API mints one (`IdentityUserMapper`): every
/// claim a string, named `id` and `role`, and owned scopes comma-separated.
String _apiJwt(Map<String, String> claims) {
  String segment(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  return '${segment(<String, Object>{'alg': 'HS256', 'typ': 'JWT'})}.'
      '${segment(<String, Object>{...claims, 'exp': 1893456000})}.'
      'signature';
}

/// Google's half, faked. No test reaches Google's SDK.
class _FakeGoogleSignInGateway implements GoogleSignInGateway {
  _FakeGoogleSignInGateway({this.signOutError});

  int signOuts = 0;

  /// What Google's sign-out throws, if anything — as the plugin can, offline
  /// on the web or when the platform refuses to clear its credential.
  final Object? signOutError;

  @override
  GoogleSignInAvailability get availability =>
      GoogleSignInAvailability.interactive;

  @override
  Future<void> initialize() async {}

  @override
  Stream<GoogleIdTokenObtained> get idTokens =>
      const Stream<GoogleIdTokenObtained>.empty();

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async =>
      const GoogleSignInCancelled();

  @override
  Future<void> signOut() async {
    signOuts++;

    if (signOutError case final error?) {
      throw error;
    }
  }
}

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

  ProviderContainer containerWith({String? scopeId}) {
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        scopeSourceProvider.overrideWithValue(FixedScopeSource(scopeId)),
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
    when(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: any(named: 'scopeId'),
      ),
    ).thenAnswer(
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

  /// A container whose session is a restored Google one, told to Google
  /// through [gateway].
  Future<ProviderContainer> googleSession(
    _FakeGoogleSignInGateway gateway,
  ) async {
    await store.write(
      AuthToken(
        value: _systemAdminJwt,
        expiresAt: DateTime.utc(2030),
        viaGoogle: true,
      ),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        tokenStoreProvider.overrideWithValue(store),
        googleSignInGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    return container;
  }

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
  });

  // The scope belongs to the calling application, as it does for Google.
  test('GivenAConfiguredScope_WhenSignedIn_ThenTheScopeIsHandedOn', () async {
    // Given
    when(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: 'scope-public-id',
      ),
    ).thenAnswer(
      (_) async => Success<LoginOutcome>(LoggedIn(tokenFor(_systemAdminJwt))),
    );
    final container = containerWith(scopeId: 'scope-public-id');

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'a@b.c', password: 'secret');

    // Then
    verify(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: 'scope-public-id',
      ),
    ).called(1);
  });

  test('GivenNoScope_WhenSignedIn_ThenNoScopeIsHandedOn', () async {
    // Given
    when(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: any(named: 'scopeId'),
      ),
    ).thenAnswer(
      (_) async => Success<LoginOutcome>(LoggedIn(tokenFor(_systemAdminJwt))),
    );
    final container = containerWith();

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'a@b.c', password: 'secret');

    // Then
    verify(
      () => repository.login(email: 'a@b.c', password: 'secret', scopeId: null),
    ).called(1);
  });

  test(
    'GivenValidCredentials_WhenSignedIn_ThenSessionIsAuthenticated',
    () async {
      // Given
      when(
        () => repository.login(
          email: 'a@b.c',
          password: 'secret',
          scopeId: any(named: 'scopeId'),
        ),
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
    when(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: any(named: 'scopeId'),
      ),
    ).thenAnswer(
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
        () => repository.login(
          email: 'a@b.c',
          password: 'secret',
          scopeId: any(named: 'scopeId'),
        ),
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
        () => repository.login(
          email: 'a@b.c',
          password: 'secret',
          scopeId: any(named: 'scopeId'),
        ),
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
        () => repository.login(
          email: 'a@b.c',
          password: 'wrong',
          scopeId: any(named: 'scopeId'),
        ),
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
    when(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: any(named: 'scopeId'),
      ),
    ).thenAnswer(
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
        () => repository.login(
          email: 'a@b.c',
          password: 'secret',
          scopeId: any(named: 'scopeId'),
        ),
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

  // AF-07e — a token rejected mid-session ends it, and the state remembers
  // that it ended rather than that the user left.
  test(
    'GivenARejectedToken_WhenSignedOutAsExpired_ThenTheReasonIsKept',
    () async {
      // Given
      final container = containerWith();
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      await controller.signOut(expired: true);

      // Then
      final state = container.read(sessionControllerProvider);
      expect((state as Unauthenticated).sessionExpired, isTrue);
    },
  );

  test('GivenADeliberateSignOut_WhenSignedOut_ThenNoReasonIsKept', () async {
    // Given
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.signOut();

    // Then
    final state = container.read(sessionControllerProvider);
    expect((state as Unauthenticated).sessionExpired, isFalse);
  });

  // AF-07g — an expired stored token is discarded at start-up, and the API is
  // never asked about it.
  test('GivenAnExpiredStoredToken_WhenRestored_ThenItIsDiscarded', () async {
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
    verifyZeroInteractions(repository);
  });

  // UI-06 sign out — a Google session ends at the API and at Google too.
  test('GivenAGoogleSession_WhenSignedOut_ThenGoogleIsToldAsWell', () async {
    // Given
    final gateway = _FakeGoogleSignInGateway();
    final store = InMemoryTokenStore();
    await store.write(
      AuthToken(
        value: _systemAdminJwt,
        expiresAt: DateTime.utc(2030),
        viaGoogle: true,
      ),
    );
    final repository = _MockAuthRepository();
    when(() => repository.signOutFromGoogle())
        .thenAnswer((_) async => const Success<void>(null));
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        tokenStoreProvider.overrideWithValue(store),
        googleSignInGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.signOut();

    // Then
    verify(() => repository.signOutFromGoogle()).called(1);
    expect(gateway.signOuts, 1);
  });

  // A password session has no Google half, so nothing is told about it.
  test('GivenAPasswordSession_WhenSignedOut_ThenGoogleIsNotCalled', () async {
    // Given
    final gateway = _FakeGoogleSignInGateway();
    final store = InMemoryTokenStore();
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final repository = _MockAuthRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        tokenStoreProvider.overrideWithValue(store),
        googleSignInGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.signOut();

    // Then
    verifyNever(() => repository.signOutFromGoogle());
    expect(gateway.signOuts, 0);
  });

  // The local session must end even when the API refuses to end its half —
  // that is the part this side actually controls.
  test(
    'GivenARefusedGoogleSignOut_WhenSignedOut_ThenTheSessionStillEnds',
    () async {
      // Given
      final gateway = _FakeGoogleSignInGateway();
      final store = InMemoryTokenStore();
      await store.write(
        AuthToken(
          value: _systemAdminJwt,
          expiresAt: DateTime.utc(2030),
          viaGoogle: true,
        ),
      );
      final repository = _MockAuthRepository();
      when(() => repository.signOutFromGoogle()).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(kind: FailureKind.unauthorized, errors: <String>['No.']),
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
          tokenStoreProvider.overrideWithValue(store),
          googleSignInGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      await controller.signOut();

      // Then
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
      expect(await store.read(), isNull);
    },
  );

  // Google's own sign-out is best-effort: when it throws, the session here
  // still ends and the stored token still goes.
  test(
    'GivenAThrowingGoogleSignOut_WhenSignedOut_ThenTheSessionEnds',
    () async {
      // Given
      when(() => repository.signOutFromGoogle())
          .thenAnswer((_) async => const Success<void>(null));
      final gateway = _FakeGoogleSignInGateway(
        signOutError: StateError('offline'),
      );
      final container = await googleSession(gateway);

      // When
      await container.read(sessionControllerProvider.notifier).signOut();

      // Then
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
      expect(await store.read(), isNull);
    },
  );

  // An API sign-out that fails with something other than a transport error —
  // an answer the client cannot read — is best-effort too, and Google is still
  // told.
  test('GivenAThrowingApiSignOut_WhenSignedOut_ThenTheSessionEnds', () async {
    // Given
    when(() => repository.signOutFromGoogle())
        .thenThrow(const FormatException('not an envelope'));
    final gateway = _FakeGoogleSignInGateway();
    final container = await googleSession(gateway);

    // When
    await container.read(sessionControllerProvider.notifier).signOut();

    // Then
    expect(gateway.signOuts, 1);
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    expect(await store.read(), isNull);
  });

  // AF-06b — a refused exchange is reported as the refusal, even when telling
  // Google about it throws, so the control that asked stops waiting.
  test(
    'GivenARefusedExchange_WhenGoogleSignOutThrows_ThenTheRefusalIsReturned',
    () async {
      // Given
      const refusal = Failure(
        kind: FailureKind.forbidden,
        errors: <String>['Google Sign-In is not enabled for this scope.'],
      );
      when(
        () => repository.signInWithGoogle(
          idToken: 'id-token',
          scopeId: any(named: 'scopeId'),
        ),
      ).thenAnswer((_) async => const FailureResult<AuthToken>(refusal));
      final gateway = _FakeGoogleSignInGateway(
        signOutError: StateError('offline'),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
          tokenStoreProvider.overrideWithValue(store),
          googleSignInGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      final result = await controller.exchangeGoogleIdToken('id-token');

      // Then
      expect(result.failureOrNull, refusal);
      expect(gateway.signOuts, 1);
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    },
  );

  // AF-05e — the API reports this with the token, so that is where the
  // principal reads it from. The JWT says nothing about it.
  test('GivenAnUnverifiedToken_WhenPrincipalRead_ThenEmailIsUnverified', () {
    // Given
    final token = AuthToken(
      value: _systemAdminJwt,
      expiresAt: DateTime.utc(2030),
      emailVerified: false,
    );

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.emailVerified, isFalse);
  });

  test('GivenAVerifiedToken_WhenPrincipalRead_ThenEmailIsVerified', () {
    // Given
    final token = AuthToken(
      value: _systemAdminJwt,
      expiresAt: DateTime.utc(2030),
    );

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.emailVerified, isTrue);
  });

  // AF-05e — verifying in this session does not get a new token from the API,
  // so the session's own answer is corrected rather than left stale.
  test(
    'GivenAnUnverifiedSession_WhenMarkedVerified_ThenThePromptEnds',
    () async {
      // Given
      await store.write(
        AuthToken(
          value: _systemAdminJwt,
          expiresAt: DateTime.utc(2030),
          emailVerified: false,
        ),
      );
      final container = containerWith();
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      await controller.markEmailVerified();

      // Then
      final state = container.read(sessionControllerProvider);
      expect((state as Authenticated).principal.emailVerified, isTrue);
    },
  );

  // And it survives a restart, or the prompt would return on the next launch.
  test('GivenAnUnverifiedSession_WhenMarkedVerified_ThenItIsStored', () async {
    // Given
    await store.write(
      AuthToken(
        value: _systemAdminJwt,
        expiresAt: DateTime.utc(2030),
        emailVerified: false,
      ),
    );
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.markEmailVerified();

    // Then
    expect((await store.read())?.emailVerified, isTrue);
  });

  // A sign-out that finishes while the verified token is being stored is not
  // undone by the write landing afterwards.
  test(
    'GivenASignOutDuringTheWrite_WhenMarkedVerified_ThenItStaysSignedOut',
    () async {
      // Given
      final held = _HeldWriteTokenStore();
      await held.write(
        AuthToken(
          value: _systemAdminJwt,
          expiresAt: DateTime.utc(2030),
          emailVerified: false,
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
          tokenStoreProvider.overrideWithValue(held),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();
      final release = held.holdNextWrite();
      final marking = controller.markEmailVerified();

      // When
      await controller.signOut();
      release();
      await marking;

      // Then
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
      expect(await held.read(), isNull);
    },
  );

  test('GivenNoSession_WhenMarkedVerified_ThenNothingIsStored', () async {
    // Given
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.markEmailVerified();

    // Then
    expect(await store.read(), isNull);
  });

  // The API names the person `id` and writes the role as a string.
  test('GivenAnApiToken_WhenPrincipalRead_ThenIdAndRoleAreRead', () {
    // Given
    final token = AuthToken(
      value: _apiJwt(<String, String>{
        'id': '6f1d3a00-0000-0000-0000-000000000003',
        'role': '3',
        'scopeId': '6f1d3a00-0000-0000-0000-0000000000aa',
      }),
      expiresAt: DateTime.utc(2030),
    );

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.id, '6f1d3a00-0000-0000-0000-000000000003');
    expect(principal.role, Role.user);
    expect(principal.scopeId, '6f1d3a00-0000-0000-0000-0000000000aa');
  });

  // A Scope Admin's owned scopes travel as one comma-separated string.
  test('GivenAScopeAdminToken_WhenPrincipalRead_ThenOwnedScopesAreSplit', () {
    // Given
    final token = AuthToken(
      value: _apiJwt(<String, String>{
        'id': '6f1d3a00-0000-0000-0000-000000000002',
        'role': '2',
        'ownedScopeIds': 'scope-a,scope-b',
      }),
      expiresAt: DateTime.utc(2030),
    );

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.role, Role.scopeAdmin);
    expect(principal.ownedScopeIds, <String>['scope-a', 'scope-b']);
  });

  test('GivenAStoredScopeAdminToken_WhenRestored_ThenTheSessionIsUp', () async {
    // Given
    await store.write(
      AuthToken(
        value: _apiJwt(<String, String>{
          'id': '6f1d3a00-0000-0000-0000-000000000002',
          'role': '2',
          'ownedScopeIds': 'scope-a,scope-b',
        }),
        expiresAt: DateTime.utc(2030),
      ),
    );
    final container = containerWith();

    // When
    await container.read(sessionControllerProvider.notifier).restore();

    // Then
    final state = container.read(sessionControllerProvider);
    expect((state as Authenticated).principal.isScopeAdmin, isTrue);
  });

  // AF-07c must end: a store that cannot be read is no session, not a wait.
  test('GivenAnUnreadableStore_WhenRestored_ThenTheSessionSettles', () async {
    // Given
    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        tokenStoreProvider.overrideWithValue(_BrokenTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    // When
    await container.read(sessionControllerProvider.notifier).restore();

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  test(
    'GivenAnUnwritableStore_WhenSignedIn_ThenTheFailureIsReported',
    () async {
      // Given
      when(
        () => repository.login(
          email: 'a@b.c',
          password: 'secret',
          scopeId: any(named: 'scopeId'),
        ),
      ).thenAnswer(
        (_) async => Success<LoginOutcome>(LoggedIn(tokenFor(_systemAdminJwt))),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
          tokenStoreProvider.overrideWithValue(_BrokenTokenStore()),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      final result = await controller.signIn(
        email: 'a@b.c',
        password: 'secret',
      );

      // Then
      expect(result.isSuccess, isFalse);
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    },
  );

  // Signing out ends the session here even when the platform refuses to
  // delete the stored token.
  test(
    'GivenAnUnclearableStore_WhenSignedOut_ThenTheSessionStillEnds',
    () async {
      // Given
      final store = _ReadableBrokenTokenStore(
        AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
          tokenStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      await controller.signOut();

      // Then
      expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    },
  );

  // UI-30 — the API marks a subject-rights-only token with a string claim.
  test('GivenASubjectRightsOnlyClaim_WhenPrincipalRead_ThenItIsRestricted', () {
    // Given
    final token = AuthToken(
      value: _apiJwt(<String, String>{
        'id': '6f1d3a00-0000-0000-0000-000000000003',
        'role': '1',
        'subjectRightsOnly': 'true',
      }),
      expiresAt: DateTime.utc(2030),
    );

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.subjectRightsOnly, isTrue);
  });

  test('GivenAFullToken_WhenPrincipalRead_ThenItIsNotRestricted', () {
    // Given
    final token = AuthToken(
      value: _apiJwt(<String, String>{
        'id': '6f1d3a00-0000-0000-0000-000000000003',
        'role': '1',
      }),
      expiresAt: DateTime.utc(2030),
    );

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.subjectRightsOnly, isFalse);
  });

  // UI-30 — what the sign-in response said is enough on its own, even for a
  // token whose payload cannot be read.
  test('GivenARestrictedResponseFlag_WhenPrincipalRead_ThenItIsRestricted', () {
    // Given
    final token = AuthToken(
      value: 'not-a-jwt',
      expiresAt: DateTime.utc(2030),
      processingRestricted: true,
    );

    // When
    final principal = principalFromToken(token);

    // Then
    expect(principal.subjectRightsOnly, isTrue);
  });

  // UI-30 main flow — AF-11i answers a password login with a restricted token.
  test(
    'GivenARestrictedPerson_WhenSignedIn_ThenTheSessionIsRestricted',
    () async {
      // Given
      when(
        () => repository.login(
          email: 'a@b.c',
          password: 'secret',
          scopeId: any(named: 'scopeId'),
        ),
      ).thenAnswer(
        (_) async => Success<LoginOutcome>(
          LoggedIn(
            AuthToken(
              value: _systemAdminJwt,
              expiresAt: DateTime.utc(2030),
              processingRestricted: true,
            ),
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
      expect((state as Authenticated).principal.subjectRightsOnly, isTrue);
    },
  );

  // UI-30 — a restricted person with two-factor authentication passes the
  // challenge first, and UC-38 then issues the restricted token.
  test(
    'GivenARestrictedPersonWithTwoFactor_WhenVerified_ThenItIsRestricted',
    () async {
      // Given
      final container = await challengedContainer();
      when(
        () => repository.verifySecondFactor(
          challengeToken: 'challenge',
          code: '123456',
          isRecoveryCode: false,
        ),
      ).thenAnswer(
        (_) async => Success<AuthToken>(
          AuthToken(
            value: _systemAdminJwt,
            expiresAt: DateTime.utc(2030),
            processingRestricted: true,
          ),
        ),
      );

      // When
      await container
          .read(sessionControllerProvider.notifier)
          .submitSecondFactor('123456');

      // Then
      final state = container.read(sessionControllerProvider);
      expect((state as Authenticated).principal.subjectRightsOnly, isTrue);
    },
  );

  // UI-30 AF-30a — a session restored from storage is read from its claim.
  test('GivenAStoredRestrictedToken_WhenRestored_ThenItIsRestricted', () async {
    // Given
    await store.write(
      AuthToken(
        value: _apiJwt(<String, String>{
          'id': '6f1d3a00-0000-0000-0000-000000000003',
          'role': '3',
          'subjectRightsOnly': 'true',
        }),
        expiresAt: DateTime.utc(2030),
      ),
    );
    final container = containerWith();

    // When
    await container.read(sessionControllerProvider.notifier).restore();

    // Then
    final state = container.read(sessionControllerProvider);
    expect((state as Authenticated).principal.subjectRightsOnly, isTrue);
  });

  // UI-30 — the sign-in screen says why the person is back there.
  test('GivenALiftedRestriction_WhenSignedOut_ThenTheReasonIsKept', () async {
    // Given
    await store.write(tokenFor(_systemAdminJwt));
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.signOut(restrictionLifted: true);

    // Then
    final state = container.read(sessionControllerProvider);
    expect((state as Unauthenticated).restrictionLifted, isTrue);
    expect(state.sessionExpired, isFalse);
  });

  // UI-08, UI-09 — a change to the person's own sign-in details revokes the
  // token that made it, and the sign-in screen says why they are there.
  test('GivenChangedSignInDetails_WhenSignedOut_ThenTheReasonIsKept', () async {
    // Given
    await store.write(tokenFor(_systemAdminJwt));
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    await controller.signOut(credentialsChanged: true);

    // Then
    final state = container.read(sessionControllerProvider);
    expect((state as Unauthenticated).credentialsChanged, isTrue);
    expect(state.sessionExpired, isFalse);
    expect(await store.read(), isNull);
  });

  // UI-33 — the sign-in screen says signing in again opens the restricted
  // session.
  test(
    'GivenARestrictionJustImposed_WhenSignedOut_ThenTheReasonIsKept',
    () async {
      // Given
      await store.write(tokenFor(_systemAdminJwt));
      final container = containerWith();
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      await controller.signOut(processingRestricted: true);

      // Then
      final state = container.read(sessionControllerProvider);
      expect((state as Unauthenticated).processingRestricted, isTrue);
      expect(state.restrictionLifted, isFalse);
      expect(state.sessionExpired, isFalse);
      expect(await store.read(), isNull);
    },
  );

  // UI-33 — once restricted, the API refuses the full token everywhere but
  // the rights endpoints, its Google sign-out included; Google still is told.
  test(
    'GivenAGoogleSessionJustRestricted_WhenSignedOut_ThenTheApiIsNotCalled',
    () async {
      // Given
      final gateway = _FakeGoogleSignInGateway();
      await store.write(
        AuthToken(
          value: _systemAdminJwt,
          expiresAt: DateTime.utc(2030),
          viaGoogle: true,
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          tokenStoreProvider.overrideWithValue(store),
          googleSignInGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      await controller.signOut(processingRestricted: true);

      // Then
      verifyNever(() => repository.signOutFromGoogle());
      expect(gateway.signOuts, 1);
    },
  );

  // UI-30 — the API's Google sign-out is not one of the four endpoints a
  // restricted token is admitted to, so it is not asked; Google still is.
  test(
    'GivenARestrictedGoogleSession_WhenSignedOut_ThenTheApiIsNotCalled',
    () async {
      // Given
      final gateway = _FakeGoogleSignInGateway();
      await store.write(
        AuthToken(
          value: _systemAdminJwt,
          expiresAt: DateTime.utc(2030),
          viaGoogle: true,
          processingRestricted: true,
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
          tokenStoreProvider.overrideWithValue(store),
          googleSignInGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);
      await controller.restore();

      // When
      await controller.signOut();

      // Then
      verifyNever(() => repository.signOutFromGoogle());
      expect(gateway.signOuts, 1);
    },
  );

  // UC-46 — the session holds the token, so the screen never handles it.
  test('GivenAChallenge_WhenACodeIsResent_ThenTheHeldTokenIsUsed', () async {
    // Given
    final container = await challengedContainer(
      methods: const <String>['Email'],
    );
    when(() => repository.resendSecondFactorCode(challengeToken: 'challenge'))
        .thenAnswer((_) async => const Success<void>(null));

    // When
    final result = await container
        .read(sessionControllerProvider.notifier)
        .resendSecondFactorCode();

    // Then
    expect(result.isSuccess, isTrue);
    verify(() => repository.resendSecondFactorCode(challengeToken: 'challenge'))
        .called(1);
  });

  test('GivenNoChallenge_WhenACodeIsResent_ThenNothingIsSent', () async {
    // Given
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();

    // When
    final result = await controller.resendSecondFactorCode();

    // Then
    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull?.errors, <String>[
      'There is no sign-in to send a code for.',
    ]);
    verifyNever(
      () => repository.resendSecondFactorCode(
        challengeToken: any(named: 'challengeToken'),
      ),
    );
  });
}

/// Reads a token but refuses to delete it.
class _ReadableBrokenTokenStore implements TokenStore {
  _ReadableBrokenTokenStore(this._token);

  final AuthToken _token;

  @override
  Future<AuthToken?> read() async => _token;

  @override
  Future<void> write(AuthToken token) async {}

  @override
  Future<void> clear() async => throw StateError('keyring locked');
}

/// An in-memory store whose next write can be held until released, so a test
/// can finish something else while it is under way.
class _HeldWriteTokenStore implements TokenStore {
  AuthToken? _token;
  Completer<void>? _hold;

  /// Holds the next write; the returned callback lets it complete.
  void Function() holdNextWrite() {
    final hold = Completer<void>();
    _hold = hold;

    return hold.complete;
  }

  @override
  Future<AuthToken?> read() async => _token;

  @override
  Future<void> write(AuthToken token) async {
    final hold = _hold;
    _hold = null;

    if (hold != null) {
      await hold.future;
    }

    _token = token;
  }

  @override
  Future<void> clear() async => _token = null;
}
