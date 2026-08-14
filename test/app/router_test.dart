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

  // UI-03 — the recovery screen is reached by someone who, by definition,
  // cannot sign in, so the guard must let them through.
  test('GivenUnauthenticated_WhenVisitingRecovery_ThenNoRedirect', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(
      session: session,
      location: '/password-recovery',
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

  // AF-02b and AF-02e — the challenge is gone, so the screen behind it is a
  // dead end and sign-in has to start over.
  test('GivenNoChallenge_WhenVisitingTheChallenge_ThenRedirectsToLogin', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(
      session: session,
      location: '/login/two-factor',
    );

    // Then
    expect(redirect, '/login');
  });

  test('GivenAuthenticated_WhenVisitingLogin_ThenRedirectsHome', () {
    // Given / When
    final redirect = redirectFor(session: authenticated, location: '/login');

    // Then
    expect(redirect, '/');
  });

  test('GivenAuthenticated_WhenLoginCarriesAFrom_ThenRedirectsToIt', () {
    // Given / When
    final redirect = redirectFor(
      session: authenticated,
      location: '/login?from=%2Fscopes%2Fabc',
    );

    // Then
    expect(redirect, '/scopes/abc');
  });

  test('GivenAuthenticated_WhenFromPointsAtLogin_ThenRedirectsHome', () {
    // Given / When
    final redirect = redirectFor(
      session: authenticated,
      location: '/login?from=%2Flogin%2Ftwo-factor',
    );

    // Then
    expect(redirect, '/');
  });

  test('GivenAuthenticated_WhenFromIsAbsolute_ThenRedirectsHome', () {
    // Given / When
    final redirect = redirectFor(
      session: authenticated,
      location: '/login?from=https%3A%2F%2Felsewhere.example.com%2Fsteal',
    );

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

  // AF-07d — a screen this role is not offered answers plainly rather than
  // bouncing the caller somewhere they did not ask for.
  test('GivenUser_WhenVisitingAnAdminRoute_ThenRedirectsToNotAvailable', () {
    // Given
    final session = Authenticated(
      token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
      principal: const Principal(id: 'id', email: 'a@b.c', role: Role.user),
    );

    // When
    final redirect = redirectFor(session: session, location: '/scopes');

    // Then
    expect(redirect, '/not-available');
  });

  test(
    'GivenScopeAdmin_WhenVisitingCreateScope_ThenRedirectsToNotAvailable',
    () {
      // Given
      final session = Authenticated(
        token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
        principal: const Principal(
          id: 'id',
          email: 'a@b.c',
          role: Role.scopeAdmin,
        ),
      );

      // When
      final redirect = redirectFor(session: session, location: '/scopes/new');

      // Then
      expect(redirect, '/not-available');
    },
  );

  // AF-07d — and the refusal screen must be reachable, or it is the redirect
  // loop the flow rules out.
  test('GivenUser_WhenVisitingNotAvailable_ThenNoRedirect', () {
    // Given
    final session = Authenticated(
      token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
      principal: const Principal(id: 'id', email: 'a@b.c', role: Role.user),
    );

    // When
    final redirect = redirectFor(session: session, location: '/not-available');

    // Then
    expect(redirect, isNull);
  });

  test('GivenUser_WhenVisitingTheirProfile_ThenNoRedirect', () {
    // Given
    final session = Authenticated(
      token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
      principal: const Principal(id: 'id', email: 'a@b.c', role: Role.user),
    );

    // When
    final redirect = redirectFor(session: session, location: '/profile');

    // Then
    expect(redirect, isNull);
  });

  // A role the guard refuses is still refused with a query string attached.
  test(
    'GivenUser_WhenAnAdminRouteCarriesAQuery_ThenRedirectsToNotAvailable',
    () {
      // Given
      final session = Authenticated(
        token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
        principal: const Principal(id: 'id', email: 'a@b.c', role: Role.user),
      );

      // When
      final redirect = redirectFor(
        session: session,
        location: '/scopes?page=2',
      );

      // Then
      expect(redirect, '/not-available');
    },
  );

  // AF-07e — a session that ended under the caller is still unauthenticated,
  // so the guard treats it exactly as it treats never having had one.
  test(
    'GivenAnExpiredSession_WhenVisitingPrivateRoute_ThenRedirectsToLogin',
    () {
      // Given
      const session = Unauthenticated(sessionExpired: true);

      // When
      final redirect = redirectFor(session: session, location: '/scopes');

      // Then
      expect(redirect, '/login?from=%2Fscopes');
    },
  );
}
