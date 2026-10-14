/// A copy of everything the API holds about the caller (UC-41), ready to be
/// saved as a file.
class DataExport {
  const DataExport({required this.document, this.exportedAt});

  /// The export as the JSON document the API returned, indented for a person
  /// to read.
  final String document;

  /// When the API assembled it, if it said.
  final DateTime? exportedAt;

  /// What to call the saved file: dated, so a second export does not land on
  /// the first.
  String get fileName {
    final at = (exportedAt ?? DateTime.now()).toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${at.year}${two(at.month)}${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}';

    return 'heimdall-data-export-$stamp.json';
  }
}

/// What a request for erasure recorded (UC-42).
class ErasureRequest {
  const ErasureRequest({
    this.requestedAt,
    this.dueAt,
    this.blocked = false,
    this.blockedReason,
  });

  final DateTime? requestedAt;

  /// The statutory deadline by which the erasure is carried out.
  final DateTime? dueAt;

  /// AF-42d — the request is recorded and the deadline runs, but something
  /// stops the identity being suspended yet: most often, that the person is
  /// the last owner of a scope.
  final bool blocked;

  /// The API's own words for what is blocking it.
  final String? blockedReason;
}

/// How a person confirms an erasure request: a person with their password, a
/// Google User with an ID token Google has just issued (UC-42 step 1).
sealed class ErasureCredential {
  const ErasureCredential();
}

final class PasswordCredential extends ErasureCredential {
  const PasswordCredential(this.password);

  final String password;
}

final class GoogleIdTokenCredential extends ErasureCredential {
  const GoogleIdTokenCredential(this.idToken);

  final String idToken;
}

/// Why a person asks for processing of their own identity to be restricted
/// (UC-44): the four grounds of GDPR Art. 18(1). The API asks for exactly one.
enum RestrictionGround {
  /// The person contests the accuracy of the data.
  accuracyContested,

  /// Processing is unlawful, and the person prefers restriction to erasure.
  unlawfulButErasureOpposed,

  /// The controller no longer needs the data, but the person needs it kept
  /// for a legal claim.
  neededForLegalClaim,

  /// The person has objected, pending verification of the controller's
  /// grounds.
  objectionPending,
}
