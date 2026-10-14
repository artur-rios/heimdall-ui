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
    this.emailVerified = true,
    this.name = '',
    this.subjectRightsOnly = false,
  });

  final String id;

  /// The address, when the token carries one. The API's own tokens do not, so
  /// this is usually empty; [displayName] is what to show.
  final String email;
  final Role role;

  /// The person's display name from the token's `name` claim, which the API
  /// writes whenever the person has one; empty otherwise.
  final String name;

  /// What to call this person on screen: the name, else the address, else
  /// nothing at all.
  String get displayName => name.isNotEmpty ? name : email;

  /// Whether the API considers this address verified.
  ///
  /// AF-05e reads it to decide whether to prompt. It defaults to `true` — a
  /// token that says nothing about verification is not evidence of an
  /// unverified address, and nagging on absent data is worse than staying
  /// quiet.
  final bool emailVerified;

  /// The scope a User belongs to; `null` for the other roles.
  final String? scopeId;

  /// The scopes a Scope Admin owns; empty for the other roles.
  final List<String> ownedScopeIds;

  /// Whether the token admits only the subject's own data-protection rights.
  ///
  /// UI-30: the API issues such a token to an identity whose processing is
  /// restricted. It names the person and their role but claims no scope, and
  /// every endpoint except the four rights endpoints refuses it with a `403` —
  /// whatever the role says. So the role is not what decides where this
  /// session may go; this is.
  final bool subjectRightsOnly;

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
  const Unauthenticated({
    this.sessionExpired = false,
    this.restrictionLifted = false,
    this.processingRestricted = false,
  });

  /// Whether this state was reached by a session ending under the caller
  /// rather than by never having had one.
  ///
  /// AF-07e: being returned to sign-in mid-task needs an explanation, and
  /// "your session ended" is a different message from "please sign in".
  final bool sessionExpired;

  /// Whether this state was reached by lifting a restriction on processing.
  ///
  /// UI-30: the token that lifted it stays confined to the rights endpoints,
  /// so the person is signed out to sign in again for full access — and the
  /// sign-in screen says that this is why, rather than leaving them to guess.
  final bool restrictionLifted;

  /// Whether this state was reached by restricting processing of the
  /// person's own account.
  ///
  /// UI-33: the API stops admitting the token that asked to anything but the
  /// rights endpoints, so the person is signed out — and the sign-in screen
  /// says that signing in again opens the restricted session (UI-30).
  final bool processingRestricted;
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
