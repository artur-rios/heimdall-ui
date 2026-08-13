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
