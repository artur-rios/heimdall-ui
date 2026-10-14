/// Whether the API would accept a credential now (UC-54).
enum CredentialStatus { live, revoked, expired }

/// One of an application's credentials, as listed. The secret is never here:
/// it is shown once, when issued, and Heimdall keeps only its hash.
class ApplicationCredential {
  const ApplicationCredential({
    required this.id,
    required this.live,
    this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.lastUsedAt,
  });

  final String id;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? lastUsedAt;

  /// The API's own verdict: not revoked and not expired.
  final bool live;

  CredentialStatus get status => live
      ? CredentialStatus.live
      : revokedAt != null
      ? CredentialStatus.revoked
      : CredentialStatus.expired;
}

/// A credential just issued (UC-53), carrying its secret — which exists in the
/// client only for as long as the one-time dialog shows it.
class IssuedCredential {
  const IssuedCredential({
    required this.id,
    required this.secret,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String secret;
  final DateTime? createdAt;
  final DateTime? expiresAt;
}

/// The expiry for a credential that should last through [pickedDay]: the last
/// millisecond of that local day, as UTC.
DateTime credentialExpiryFor(DateTime pickedDay) => DateTime(
  pickedDay.year,
  pickedDay.month,
  pickedDay.day,
  23,
  59,
  59,
  999,
).toUtc();
