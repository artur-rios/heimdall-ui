import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/route_access.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';

void main() {
  // Every signed-in caller has a home, an account, and — so AF-07d cannot
  // loop — the refusal screen itself.
  for (final path in <String>['/', '/profile', '/profile/security']) {
    for (final role in Role.values) {
      test('Given${role.name}_WhenAsking${path}_ThenItIsAllowed', () {
        // Given / When
        final allowed = roleMayReach(role: role, path: path);

        // Then
        expect(allowed, isTrue);
      });
    }
  }

  test('GivenAnyRole_WhenAskingTheRefusalScreen_ThenItIsAllowed', () {
    // Given / When / Then
    for (final role in Role.values) {
      expect(roleMayReach(role: role, path: '/not-available'), isTrue);
    }
  });

  // Scope listing: all scopes for a System Admin, owned ones for a Scope
  // Admin, hidden for a User.
  test('GivenSystemAdmin_WhenAskingScopes_ThenItIsAllowed', () {
    // Given / When
    final allowed = roleMayReach(role: Role.systemAdmin, path: '/scopes');

    // Then
    expect(allowed, isTrue);
  });

  test('GivenScopeAdmin_WhenAskingScopes_ThenItIsAllowed', () {
    // Given / When
    final allowed = roleMayReach(role: Role.scopeAdmin, path: '/scopes');

    // Then
    expect(allowed, isTrue);
  });

  test('GivenUser_WhenAskingScopes_ThenItIsRefused', () {
    // Given / When
    final allowed = roleMayReach(role: Role.user, path: '/scopes');

    // Then
    expect(allowed, isFalse);
  });

  test('GivenUser_WhenAskingAScopesSubRoute_ThenItIsRefused', () {
    // Given / When
    final allowed = roleMayReach(
      role: Role.user,
      path: '/scopes/scope-id/persons',
    );

    // Then
    expect(allowed, isFalse);
  });

  // Creating a scope is the System Admin's alone.
  test('GivenScopeAdmin_WhenAskingCreateScope_ThenItIsRefused', () {
    // Given / When
    final allowed = roleMayReach(role: Role.scopeAdmin, path: '/scopes/new');

    // Then
    expect(allowed, isFalse);
  });

  test('GivenSystemAdmin_WhenAskingCreateScope_ThenItIsAllowed', () {
    // Given / When
    final allowed = roleMayReach(role: Role.systemAdmin, path: '/scopes/new');

    // Then
    expect(allowed, isTrue);
  });

  // Health: full for a System Admin, read-only for a Scope Admin, hidden for
  // a User — read-only is still reaching it.
  test('GivenScopeAdmin_WhenAskingHealth_ThenItIsAllowed', () {
    // Given / When
    final allowed = roleMayReach(role: Role.scopeAdmin, path: '/health');

    // Then
    expect(allowed, isTrue);
  });

  test('GivenUser_WhenAskingHealth_ThenItIsRefused', () {
    // Given / When
    final allowed = roleMayReach(role: Role.user, path: '/health');

    // Then
    expect(allowed, isFalse);
  });

  // A route nobody has built is the error screen's business: answering "not
  // for your role" would be a guess about a screen that does not exist.
  test('GivenAnyRole_WhenAskingAnUnknownRoute_ThenItIsAllowed', () {
    // Given / When
    final allowed = roleMayReach(role: Role.user, path: '/nothing-here');

    // Then
    expect(allowed, isTrue);
  });
}
