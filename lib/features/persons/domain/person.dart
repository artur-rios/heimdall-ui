import '../../auth/domain/session.dart';

/// A person as the API describes one.
///
/// The generated output makes every field nullable, because the same shape
/// serves several endpoints. Here the fields the interface actually renders are
/// non-nullable with defined fallbacks, so no screen has to decide what an
/// absent name means.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.emailVerified = true,
    this.twoFactorEnabled = false,
    this.isDeleted = false,
    this.scopeId,
    this.ownedScopeIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final Role role;

  /// Whether the API considers this address verified. Defaults to `true` for
  /// the same reason [Principal.emailVerified] does: silence is not evidence of
  /// an unverified address.
  final bool emailVerified;

  /// Whether the person has a second factor configured. Defaults to `false`:
  /// the endpoints that do not report it are the ones where nobody could have
  /// configured one yet.
  final bool twoFactorEnabled;

  /// Whether the person has been logically deleted. The listings show these
  /// only when the user asks for them.
  final bool isDeleted;

  /// The scope a User belongs to; `null` for the other roles.
  final String? scopeId;

  /// The scopes a Scope Admin owns; empty for the other roles.
  final List<String> ownedScopeIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The same person carrying a second-factor state read elsewhere.
  ///
  /// The update endpoint answers with a shape that does not report one, and an
  /// edit to a name and an address cannot have turned anybody's second factor
  /// on or off — so what was already read still holds, and `false` would be a
  /// guess rather than a fact.
  Person withTwoFactorEnabled(bool enabled) => Person(
    id: id,
    name: name,
    email: email,
    role: role,
    emailVerified: emailVerified,
    twoFactorEnabled: enabled,
    isDeleted: isDeleted,
    scopeId: scopeId,
    ownedScopeIds: ownedScopeIds,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// A Scope Admin as the owner listing projects one: enough to recognise and to
/// name, and nothing else.
///
/// The endpoint behind it answers with its own shape rather than with a person,
/// because choosing an owner needs a name and an address, not a role, a scope,
/// or a deletion state.
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}
