import '../../auth/domain/session.dart';

/// How a role is written wherever one is shown.
String roleLabel(Role role) => switch (role) {
  Role.systemAdmin => 'System Admin',
  Role.scopeAdmin => 'Scope Admin',
  Role.user => 'User',
};
