/// An application as the API describes one.
class Application {
  const Application({
    required this.id,
    required this.name,
    required this.ownerId,
    this.scopeId,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// The person who owns it. FR-AP-08: the interface resolves this to a person
  /// where it can, and shows the identifier where it cannot.
  final String ownerId;

  final String? scopeId;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
