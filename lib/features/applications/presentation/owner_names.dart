import '../../../core/result/result.dart';
import '../../persons/domain/person_repository.dart';

/// Resolves owner identifiers to person names, and remembers what it learned.
///
/// FR-AP-08: an application carries an owner identifier, and the interface
/// shows a name where it can. AF-20d is the other half — an owner that cannot
/// be resolved is shown by its identifier rather than blanking the row.
///
/// Only a definite answer is remembered: a name, or the API saying there is no
/// such person, which is not retried on every page. A read that merely failed
/// — the network, say — is asked again next time rather than pinning the
/// owner to their identifier for the rest of the session.
class OwnerNames {
  OwnerNames(this._repository);

  final PersonRepository _repository;

  /// Identifier to name, or to `null` when the API says nobody has it.
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

        switch (person) {
          case Success(:final value):
            _known[id] = value.name;
          case FailureResult(:final failure)
              when failure.kind == FailureKind.notFound:
            _known[id] = null;
          case FailureResult():
            // Not an answer about the person, so nothing to remember.
            break;
        }
      }),
    );
  }

  /// Forgets every name learned, so the next [resolve] reads them afresh — a
  /// person renamed since is then shown by their new name.
  void forget() => _known.clear();
}
