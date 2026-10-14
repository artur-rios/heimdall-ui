/// A self-registration awaiting confirmation (UC-49). Its password hash, salt
/// and token never reach the client.
class PendingRegistration {
  const PendingRegistration({
    required this.id,
    required this.name,
    required this.email,
    required this.attemptsLeft,
    required this.expired,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String name;
  final String email;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// Wrong confirmation passwords it may still take; never below zero.
  final int attemptsLeft;

  /// Past its expiry and waiting for the retention pass to remove it.
  final bool expired;
}
