import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/router.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';

void main() {
  final authenticated = Authenticated(
    token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
    principal: const Principal(
      id: 'id',
      email: 'a@b.c',
      role: Role.systemAdmin,
    ),
  );

  test(
    'GivenUnauthenticated_WhenVisitingPrivateRoute_ThenRedirectsToLogin',
    () {
      // Given
      const session = Unauthenticated();

      // When
      final redirect = redirectFor(session: session, location: '/scopes');

      // Then
      expect(redirect, '/login?from=%2Fscopes');
    },
  );

  test('GivenUnauthenticated_WhenVisitingLogin_ThenNoRedirect', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(session: session, location: '/login');

    // Then
    expect(redirect, isNull);
  });

  test('GivenUnauthenticated_WhenVisitingResetLink_ThenNoRedirect', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(
      session: session,
      location: '/password-reset?token=abc',
    );

    // Then
    expect(redirect, isNull);
  });

  test('GivenChallenged_WhenVisitingAnyRoute_ThenRedirectsToTheChallenge', () {
    // Given
    const session = Challenged(
      challengeToken: 'challenge',
      availableMethods: <String>['Totp'],
    );

    // When
    final redirect = redirectFor(session: session, location: '/scopes');

    // Then
    expect(redirect, '/login/two-factor');
  });

  test('GivenChallenged_WhenAlreadyOnTheChallenge_ThenNoRedirect', () {
    // Given
    const session = Challenged(
      challengeToken: 'challenge',
      availableMethods: <String>['Totp'],
    );

    // When
    final redirect = redirectFor(
      session: session,
      location: '/login/two-factor',
    );

    // Then
    expect(redirect, isNull);
  });

  test('GivenAuthenticated_WhenVisitingLogin_ThenRedirectsHome', () {
    // Given / When
    final redirect = redirectFor(session: authenticated, location: '/login');

    // Then
    expect(redirect, '/');
  });

  test('GivenAuthenticated_WhenVisitingPrivateRoute_ThenNoRedirect', () {
    // Given / When
    final redirect = redirectFor(session: authenticated, location: '/scopes');

    // Then
    expect(redirect, isNull);
  });

  test('GivenSessionRestoring_WhenVisitingAnyRoute_ThenNoRedirect', () {
    // Given
    const session = SessionRestoring();

    // When
    final redirect = redirectFor(session: session, location: '/scopes');

    // Then
    expect(redirect, isNull);
  });
}
