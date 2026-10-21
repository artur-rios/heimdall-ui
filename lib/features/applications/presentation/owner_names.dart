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
///
/// What is remembered is remembered for [timeToLive] (#179): long enough that
/// leaving the list and coming back does not re-read every owner, short enough
/// that a renamed owner is shown by their new name soon, and at once after an
/// explicit refresh ([forget]).
class OwnerNames {
  OwnerNames(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// How long a learned name is trusted.
  static const Duration timeToLive = Duration(minutes: 5);

  final PersonRepository _repository;
  final DateTime Function() _now;

  /// Identifier to name, or to `null` when the API says nobody has it, with
  /// when that was learned.
  final Map<String, _Known> _known = <String, _Known>{};

  /// The name to show for [ownerId] — the identifier itself until something
  /// better is known, which is also the permanent answer for AF-20d.
  String labelFor(String ownerId) => _known[ownerId]?.name ?? ownerId;

  /// Reads whichever of [ownerIds] have not been looked up yet, or were looked
  /// up more than [timeToLive] ago. An old name stays on show if its re-read
  /// fails, rather than falling back to the identifier.
  ///
  /// Deduplicated and run together: a page of twenty applications owned by two
  /// people costs two requests, not twenty.
  Future<void> resolve(Iterable<String> ownerIds) async {
    final now = _now();
    final unknown = ownerIds
        .where((id) => id.isNotEmpty && !_isFresh(id, now))
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
            _known[id] = _Known(value.name, now);
          case FailureResult(:final failure)
              when failure.kind == FailureKind.notFound:
            _known[id] = _Known(null, now);
          case FailureResult():
            // Not an answer about the person, so nothing to remember.
            break;
        }
      }),
    );
  }

  bool _isFresh(String id, DateTime now) {
    final known = _known[id];

    return known != null && now.difference(known.learnedAt) < timeToLive;
  }

  /// Forgets every name learned, so the next [resolve] reads them afresh — a
  /// person renamed since is then shown by their new name.
  void forget() => _known.clear();
}

class _Known {
  const _Known(this.name, this.learnedAt);

  final String? name;
  final DateTime learnedAt;
}
