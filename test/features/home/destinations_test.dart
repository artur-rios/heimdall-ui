import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/route_access.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/home/presentation/destinations.dart';

void main() {
  // Navigation never offers what the route guard would refuse, and never
  // hides what it allows: the two read the same Authorization Matrix.
  for (final role in Role.values) {
    test('GivenARole_WhenNavigationIsBuilt_ThenItMatchesTheGuard: $role', () {
      // Given
      final principal = Principal(id: 'p', email: '', role: role);

      // When
      final routes = destinationsFor(
        principal,
      ).map((destination) => destination.route).toSet();

      // Then
      for (final route in <String>['/scopes', '/profile', '/health']) {
        expect(
          routes.contains(route),
          roleMayReach(role: role, path: route),
          reason: '$route for $role',
        );
      }
    });
  }
}
