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

  // AF-07a — the deep link survives the second factor.
  test('GivenChallengedOnLoginWithFrom_WhenRedirected_ThenFromIsCarried', () {
    // Given
    const session = Challenged(
      challengeToken: 'challenge',
      availableMethods: <String>['Totp'],
    );

    // When
    final redirect = redirectFor(
      session: session,
      location: '/login?from=%2Fscopes%2FX%2Fapplications',
    );

    // Then
    expect(redirect, '/login/two-factor?from=%2Fscopes%2FX%2Fapplications');
  });

  test('GivenChallengedWithFrom_WhenAuthenticated_ThenLandsOnTheDeepLink', () {
    // Given / When
    final redirect = redirectFor(
      session: authenticated,
      location: '/login/two-factor?from=%2Fscopes%2FX%2Fapplications',
    );

    // Then
    expect(redirect, '/scopes/X/applications');
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

  // Issue #73: Google's consent screen links here, so it must open for
  // someone who has never signed in.
  test('GivenUnauthenticated_WhenVisitingPrivacy_ThenNoRedirect', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(session: session, location: '/privacy');

    // Then
    expect(redirect, isNull);
  });

  test('GivenAnyRole_WhenVisitingPrivacy_ThenNoRedirect', () {
    for (final role in Role.values) {
      // Given
      final session = Authenticated(
        token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
        principal: Principal(id: 'id', email: 'a@b.c', role: role),
      );

      // When
      final redirect = redirectFor(session: session, location: '/privacy');

      // Then
      expect(redirect, isNull, reason: role.name);
    }
  });

  /// A subject-rights-only session (UI-30) holding [role].
  Authenticated restricted({Role role = Role.systemAdmin}) => Authenticated(
    token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
    principal: Principal(
      id: 'id',
      email: 'a@b.c',
      role: role,
      subjectRightsOnly: true,
    ),
  );

  // UI-30 — every other screen would only answer 403, whatever the role.
  test('GivenARestrictedSession_WhenVisitingAnyRoute_ThenRedirectsToIt', () {
    for (final role in Role.values) {
      for (final location in <String>['/', '/scopes', '/profile', '/health']) {
        // Given
        final session = restricted(role: role);

        // When
        final redirect = redirectFor(session: session, location: location);

        // Then
        expect(redirect, restrictedRoute, reason: '${role.name} $location');
      }
    }
  });

  // UI-30 — the redirect must stop at the screen it sends to.
  test('GivenARestrictedSession_WhenOnTheRestrictedScreen_ThenNoRedirect', () {
    // Given
    final session = restricted();

    // When
    final redirect = redirectFor(session: session, location: restrictedRoute);

    // Then
    expect(redirect, isNull);
  });

  // UI-30 — the privacy notice says what the rights on that screen are.
  test('GivenARestrictedSession_WhenVisitingPrivacy_ThenNoRedirect', () {
    // Given
    final session = restricted();

    // When
    final redirect = redirectFor(session: session, location: '/privacy');

    // Then
    expect(redirect, isNull);
  });

  // UI-30 — signing in with a restricted token lands on its screen, not on the
  // screen the person first asked for.
  test('GivenARestrictedSession_WhenOnLoginWithAFrom_ThenRedirectsToIt', () {
    // Given
    final session = restricted();

    // When
    final redirect = redirectFor(
      session: session,
      location: '/login?from=%2Fscopes',
    );

    // Then
    expect(redirect, restrictedRoute);
  });

  test('GivenARestrictedSession_WhenOnNotAvailable_ThenRedirectsToIt', () {
    // Given
    final session = restricted(role: Role.user);

    // When
    final redirect = redirectFor(session: session, location: '/not-available');

    // Then
    expect(redirect, restrictedRoute);
  });

  // UI-30 — a full session has no restriction to lift.
  test('GivenAFullSession_WhenVisitingTheRestrictedScreen_ThenGoesHome', () {
    // Given
    final session = authenticated;

    // When
    final redirect = redirectFor(session: session, location: restrictedRoute);

    // Then
    expect(redirect, '/');
  });

  test('GivenUnauthenticated_WhenVisitingTheRestrictedScreen_ThenToLogin', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(session: session, location: restrictedRoute);

    // Then
    expect(redirect, '/login?from=%2Frestricted');
  });

  // Following the guard from any route must settle, never bounce.
  test('GivenARestrictedSession_WhenRedirectsAreFollowed_ThenTheySettle', () {
    for (final start in <String>['/', '/login', '/scopes/x/persons', '/x']) {
      // Given
      final session = restricted();
      var location = start;

      // When
      for (var hop = 0; hop < 5; hop++) {
        final next = redirectFor(session: session, location: location);

        if (next == null) {
          break;
        }

        location = next;
      }

      // Then
      expect(redirectFor(session: session, location: location), isNull);
      expect(location, restrictedRoute, reason: start);
    }
  });

  // Every id in a route is a PublicId GUID. Anything else, above all a decoded
  // path such as `../../persons/<id>?x=`, is a link to nothing: it must not
  // reach a screen, which would hand it to the API as part of a path.
  const guid = '6f1d3a00-0000-0000-0000-000000000001';

  test('GivenATraversalId_WhenVisitingItsRoute_ThenRedirectsToNotFound', () {
    // Given
    const location =
        '/scopes/..%2F..%2Fpersons%2F$guid%3Fx%3D/google-users/$guid';

    // When
    final redirect = redirectFor(
      session: authenticated,
      location: location,
      pathParameters: const <String, String>{
        'scopeId': '../../persons/$guid?x=',
        'googleUserId': guid,
      },
    );

    // Then
    expect(redirect, notFoundRoute);
  });

  test('GivenANonGuidId_WhenVisitingItsRoute_ThenRedirectsToNotFound', () {
    // Given
    const location = '/scopes/$guid/applications/app-1';

    // When
    final redirect = redirectFor(
      session: authenticated,
      location: location,
      pathParameters: const <String, String>{
        'scopeId': guid,
        'applicationId': 'app-1',
      },
    );

    // Then
    expect(redirect, notFoundRoute);
  });

  test('GivenWellFormedIds_WhenVisitingTheirRoute_ThenNoRedirect', () {
    // Given
    const location = '/scopes/$guid/google-users/$guid';

    // When
    final redirect = redirectFor(
      session: authenticated,
      location: location,
      pathParameters: const <String, String>{
        'scopeId': guid,
        'googleUserId': guid,
      },
    );

    // Then
    expect(redirect, isNull);
  });

  // A link to nothing is a link to nothing whoever follows it; signing in
  // first would not change that.
  test('GivenUnauthenticated_WhenVisitingAMalformedId_ThenToNotFound', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(
      session: session,
      location: '/persons/..',
      pathParameters: const <String, String>{'personId': '..'},
    );

    // Then
    expect(redirect, notFoundRoute);
  });

  test('GivenUnauthenticated_WhenVisitingNotFound_ThenNoRedirect', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(session: session, location: notFoundRoute);

    // Then
    expect(redirect, isNull);
  });
}
