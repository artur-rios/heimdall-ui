import '../../../core/result/result.dart';
import 'person.dart';

/// The person operations the interface depends on.
///
/// Implemented in `features/persons/data` over the generated client, and faked
/// in tests — which is why nothing here mentions a transport.
abstract interface class PersonRepository {
  /// Reads one person by their public identifier.
  ///
  /// A `404` surfaces as [FailureKind.notFound], which is what lets UI-08's
  /// AF-08e tell "deleted from under the session" apart from any other refusal.
  Future<Result<Person>> getById(String id, {bool includeDeleted = false});

  /// Updates a person's name and email.
  ///
  /// [roleId] is the API's own role change, which only a System Admin may make.
  /// An ordinary edit leaves it null, which is how the command says "unchanged".
  Future<Result<Person>> update({
    required String id,
    required String name,
    required String email,
    int? roleId,
  });
}
