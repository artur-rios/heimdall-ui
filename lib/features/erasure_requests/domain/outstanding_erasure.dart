/// One erasure request the anonymisation pass has not carried out yet
/// (UC-43). It names nobody: the subject asked to be erased, and the queue an
/// administrator works from is the last place to widen who sees them.
class OutstandingErasure {
  const OutstandingErasure({
    required this.subjectId,
    required this.isGoogleUser,
    required this.overdue,
    this.requestedAt,
    this.dueAt,
    this.blockedReason,
  });

  final String subjectId;
  final bool isGoogleUser;
  final DateTime? requestedAt;
  final DateTime? dueAt;
  final bool overdue;

  /// Why the pass cannot carry it out yet — usually that the subject is a
  /// scope's last owner. These are the requests that need an administrator.
  final String? blockedReason;
}

/// What re-applying erasures after a restore found.
class ReconciliationOutcome {
  const ReconciliationOutcome({
    required this.anonymised,
    required this.alreadyAnonymised,
    required this.notFound,
  });

  /// Identities the restore had brought back, now anonymised again.
  final int anonymised;
  final int alreadyAnonymised;

  /// Identifiers nothing answers to — the ordinary case for most of a ledger.
  final List<String> notFound;
}

/// A pasted ledger, split into identifiers and what is not one.
class ParsedSubjectIds {
  const ParsedSubjectIds({required this.ids, required this.invalid});

  final List<String> ids;
  final List<String> invalid;

  bool get isEmpty => ids.isEmpty && invalid.isEmpty;
}

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Splits [text] on commas and whitespace, keeps each identifier once
/// (lowercased, in first-seen order), and lists every entry that is not one (also once each).
ParsedSubjectIds parseSubjectIds(String text) {
  final ids = <String>[];
  final seen = <String>{};
  final invalid = <String>[];
  final seenInvalid = <String>{};

  for (final entry in text.split(RegExp(r'[\s,]+'))) {
    if (entry.isEmpty) {
      continue;
    }

    if (!_uuid.hasMatch(entry)) {
      if (seenInvalid.add(entry)) {
        invalid.add(entry);
      }

      continue;
    }

    final id = entry.toLowerCase();

    if (seen.add(id)) {
      ids.add(id);
    }
  }

  return ParsedSubjectIds(ids: ids, invalid: invalid);
}
