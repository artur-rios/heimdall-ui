import '../features/auth/domain/session.dart';

/// Whether [role] is offered the screen behind [path].
///
/// Reads the Authorization Matrix in the System Requirements Document, and
/// nothing more. This is a usability decision, not a security one: the API
/// refuses whatever a caller may not do, whether or not the interface offered
/// it — so a rule that is wrong here shows the wrong menu, never grants access.
///
/// Scope-level ownership ("owned scopes only") is deliberately absent. It is a
/// per-record question the API answers on the record, and a path alone cannot
/// tell an owned scope from any other; the screens enforce what the API says.
bool roleMayReach({required Role role, required String path}) => switch (path) {
  // Every signed-in caller has a home and an account of their own — and the
  // refusal screen itself, or AF-07d would be the redirect loop it forbids.
  '/' || '/not-available' => true,
  final String p when p == '/profile' || p.startsWith('/profile/') => true,
  // Creating and permanently deleting a scope is the System Admin's alone.
  '/scopes/new' => role == Role.systemAdmin,
  final String p when p == '/scopes' || p.startsWith('/scopes/') =>
    role != Role.user,
  // Full for a System Admin, read-only for a Scope Admin, hidden for a User.
  '/health' => role != Role.user,
  // A route nobody has built yet is the error screen's business, not the
  // guard's: answering "not for your role" would be a guess about a screen
  // that does not exist.
  _ => true,
};
