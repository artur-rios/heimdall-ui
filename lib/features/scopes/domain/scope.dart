/// A scope as the API describes one.
///
/// The generated output makes every field nullable because one shape serves
/// several endpoints. Here the fields the interface renders are non-nullable
/// with defined fallbacks, so no screen has to decide what an absent name means.
class Scope {
  const Scope({
    required this.id,
    required this.name,
    required this.description,
    this.googleSignInEnabled = false,
    this.isDeleted = false,
    this.ownerIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;

  /// Whether people may sign in to this scope with Google. UI-15 toggles it.
  final bool googleSignInEnabled;

  /// Whether the scope has been logically deleted. The listing shows these only
  /// when the user asks for them.
  final bool isDeleted;

  final List<String> ownerIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get ownerCount => ownerIds.length;
}
