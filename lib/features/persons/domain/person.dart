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

  /// Whether the person has been logically deleted. The listings show these
  /// only when the user asks for them.
  final bool isDeleted;

  /// The scope a User belongs to; `null` for the other roles.
  final String? scopeId;

  /// The scopes a Scope Admin owns; empty for the other roles.
  final List<String> ownedScopeIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;
}
