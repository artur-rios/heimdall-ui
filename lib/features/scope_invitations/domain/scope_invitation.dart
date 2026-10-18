/// An open invitation to co-own a scope, as that scope's owners see it
/// (UC-58): who is invited, by whom, and until when. The person owns nothing
/// until they accept it.
class OwnerInvitation {
  const OwnerInvitation({
    required this.id,
    required this.inviteeId,
    required this.inviteeName,
    required this.inviteeEmail,
    this.invitedByName,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String inviteeId;
  final String inviteeName;
  final String inviteeEmail;

  /// Who invited them; `null` once that administrator's record was erased.
  final String? invitedByName;
  final DateTime? createdAt;
  final DateTime? expiresAt;
}

/// An open invitation the signed-in administrator may accept or decline
/// (UC-59).
class ScopeInvitation {
  const ScopeInvitation({
    required this.id,
    required this.scopeId,
    required this.scopeName,
    this.invitedByName,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String scopeId;
  final String scopeName;

  /// Who invited them; `null` once that administrator's record was erased.
  final String? invitedByName;
  final DateTime? createdAt;
  final DateTime? expiresAt;
}
