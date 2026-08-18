/// A scope permission as the API describes one.
class ScopePermission {
  const ScopePermission({
    required this.id,
    required this.name,
    required this.description,
    this.includeAsJwtClaim = false,
    this.scopeId,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;

  /// Whether the permission is issued in the scope's tokens. FR-PM-04: the
  /// interface says so where it is set, because it is the difference between a
  /// record and something the scope's users actually carry.
  final bool includeAsJwtClaim;

  final String? scopeId;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
