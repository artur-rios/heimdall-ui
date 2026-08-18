import '../../persons/domain/person_repository.dart';

/// Resolves owner identifiers to person names, and remembers what it learned.
///
/// FR-AP-08: an application carries an owner identifier, and the interface
/// shows a name where it can. AF-20d is the other half — an owner that cannot
/// be resolved is shown by its identifier rather than blanking the row, which
/// is why a failed read is remembered as "unresolvable" and not retried on
/// every page.
class OwnerNames {
  OwnerNames(this._repository);

  final PersonRepository _repository;

  /// Identifier to name, or to `null` when the API would not tell us.
  final Map<String, String?> _known = <String, String?>{};

  /// The name to show for [ownerId] — the identifier itself until something
  /// better is known, which is also the permanent answer for AF-20d.
  String labelFor(String ownerId) => _known[ownerId] ?? ownerId;

  /// Reads whichever of [ownerIds] have not been looked up yet.
  ///
  /// Deduplicated and run together: a page of twenty applications owned by two
  /// people costs two requests, not twenty.
  Future<void> resolve(Iterable<String> ownerIds) async {
    final unknown = ownerIds
        .where((id) => id.isNotEmpty && !_known.containsKey(id))
        .toSet();

    if (unknown.isEmpty) {
      return;
    }

    await Future.wait<void>(
      unknown.map((id) async {
        // Deleted persons still own applications, and a row that says the
        // identifier because the owner was deleted is worse than one that
        // names them.
        final person = await _repository.getById(id, includeDeleted: true);
        _known[id] = person.valueOrNull?.name;
      }),
    );
  }
}
