/// A Google User as the API describes one.
///
/// A Google User is not a Person: it is an account that reached a scope through
/// Google's sign-in rather than through a password. Its fields come from
/// Google, which is why AF-28e makes it read-only here.
class GoogleUser {
  const GoogleUser({
    required this.id,
    required this.name,
    required this.email,
    this.googleId,
    this.emailVerified = true,
    this.profilePictureUrl,
    this.isDeleted = false,
    this.scopeId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;

  /// Google's own identifier for the account.
  final String? googleId;

  /// Whether Google considers the address verified.
  final bool emailVerified;

  /// Where the account's picture lives, when Google reported one.
  final String? profilePictureUrl;

  final bool isDeleted;
  final String? scopeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The letters shown when there is no picture to show (AF-28d, FR-GU-03).
  ///
  /// Runes rather than code units, so a name starting with an emoji or a
  /// non-BMP character is not cut in half.
  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) {
      return email.isEmpty ? '?' : _firstLetterOf(email);
    }

    if (words.length == 1) {
      return _firstLetterOf(words.first);
    }

    return _firstLetterOf(words.first) + _firstLetterOf(words.last);
  }

  static String _firstLetterOf(String value) =>
      String.fromCharCodes(value.runes.take(1)).toUpperCase();
}
