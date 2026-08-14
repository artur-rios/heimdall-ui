import '../../../core/storage/token_store.dart';

/// The API's roles, by the values it stores and puts in a token's claims.
enum Role {
  systemAdmin(1),
  scopeAdmin(2),
  user(3);

  const Role(this.value);

  final int value;
}

/// Reads a role from its stored value, falling back to the least privileged one
/// so a malformed or unexpected value can never widen access.
Role roleFromValue(int value) => Role.values.firstWhere(
  (role) => role.value == value,
  orElse: () => Role.user,
);

/// Who the session belongs to, as read from the token's claims.
class Principal {
  const Principal({
    required this.id,
    required this.email,
    required this.role,
    this.scopeId,
    this.ownedScopeIds = const <String>[],
  });

  final String id;
  final String email;
  final Role role;

  /// The scope a User belongs to; `null` for the other roles.
  final String? scopeId;

  /// The scopes a Scope Admin owns; empty for the other roles.
  final List<String> ownedScopeIds;

  bool get isSystemAdmin => role == Role.systemAdmin;
  bool get isScopeAdmin => role == Role.scopeAdmin;

  /// Whether this principal is offered the administrative sections at all.
  bool get administersAnything => isSystemAdmin || isScopeAdmin;
}

/// Every state the session can be in.
sealed class SessionState {
  const SessionState();
}

/// The session is being restored from storage at start-up. Routing waits this
/// out rather than treating it as signed out, so a slow read cannot bounce a
/// returning user to the sign-in screen.
final class SessionRestoring extends SessionState {
  const SessionRestoring();
}

/// No valid session exists.
final class Unauthenticated extends SessionState {
  const Unauthenticated();
}

/// Credentials were accepted but a second factor is still outstanding. The
/// challenge token is valid for `POST /api/auth/2fa/verify` and nothing else,
/// and is never persisted.
final class Challenged extends SessionState {
  const Challenged({
    required this.challengeToken,
    required this.availableMethods,
    this.selectedMethod,
  });

  final String challengeToken;
  final List<String> availableMethods;

  /// The method the user is answering with, when they chose one. It lives here
  /// rather than in the screen so the choice survives a rebuild and lasts for
  /// the challenge, as AF-02c requires.
  final String? selectedMethod;

  /// The method actually in use: the chosen one, or the first the API offered.
  String? get methodInUse =>
      selectedMethod ??
      (availableMethods.isEmpty ? null : availableMethods.first);

  Challenged withMethod(String method) => Challenged(
    challengeToken: challengeToken,
    availableMethods: availableMethods,
    selectedMethod: method,
  );
}

/// A usable session.
final class Authenticated extends SessionState {
  const Authenticated({required this.token, required this.principal});

  final AuthToken token;
  final Principal principal;
}
