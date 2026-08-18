import '../../../core/network/envelope.dart';
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

  /// Lists the Scope Admins who own a scope.
  Future<Result<Page<Person>>> listScopeOwners({
    required String scopeId,
    String? name,
    String? email,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Lists the User persons of a scope.
  ///
  /// UI-14 reads it to offer the promotion, and UI-16 lists it in its own
  /// right.
  Future<Result<Page<Person>>> listScopePersons({
    required String scopeId,
    String? name,
    String? email,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Adds an existing Scope Admin as a co-owner of a scope.
  ///
  /// Whether that person is a usable Scope Admin, and whether they already own
  /// the scope, are the API's questions — AF-14b and AF-14c are what its
  /// answers look like.
  Future<Result<void>> addScopeOwner({
    required String scopeId,
    required String personId,
  });

  /// Creates a brand-new Scope Admin directly as a co-owner of a scope.
  Future<Result<Person>> createScopeOwner({
    required String scopeId,
    required String name,
    required String email,
    required String password,
  });

  /// Removes a person's ownership of a scope.
  ///
  /// AF-14a: the API refuses to leave a scope with no owner, and says so in
  /// its own words.
  Future<Result<void>> removeScopeOwner({
    required String scopeId,
    required String personId,
  });

  /// Promotes a User of the scope to Scope Admin, making them a co-owner.
  Future<Result<void>> promoteScopeUser({
    required String scopeId,
    required String personId,
  });
}
