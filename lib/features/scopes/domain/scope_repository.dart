import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'scope.dart';

/// The scope operations the interface depends on.
///
/// Implemented in `features/scopes/data` over the generated client, and faked
/// in tests — which is why nothing here mentions a transport.
abstract interface class ScopeRepository {
  /// Reads one page of scopes.
  ///
  /// The API decides what the caller may see: a System Admin gets every scope,
  /// a Scope Admin only the ones they own (AF-10c). Nothing here filters by
  /// ownership, because the interface is not the authority on that.
  Future<Result<Page<Scope>>> list({
    String? name,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Creates a scope.
  ///
  /// [ownerIds] names the persons who will own it. Whether each is a usable
  /// Scope Admin is the API's question, not this layer's — AF-11c is what its
  /// answer looks like when one is not.
  Future<Result<Scope>> create({
    required String name,
    required String description,
    required List<String> ownerIds,
  });

  /// Reads one scope.
  ///
  /// [includeDeleted] is on by default for the detail screen: AF-12d shows a
  /// logically deleted scope read-only, and it cannot do that if the API is
  /// asked to pretend the scope is gone.
  Future<Result<Scope>> getById(String id, {bool includeDeleted = true});

  /// Updates a scope's name and description.
  Future<Result<Scope>> update({
    required String id,
    required String name,
    required String description,
  });

  /// Turns Google Sign-In on or off for a scope.
  ///
  /// Returns the scope as the API now holds it, so the control settles on the
  /// confirmed state rather than on the one it was moved to.
  Future<Result<Scope>> setGoogleSignIn({
    required String id,
    required bool enabled,
  });

  /// Logically deletes a scope. The record is kept and the API can restore it.
  Future<Result<void>> delete(String id);

  /// Permanently deletes a scope and everything it holds. Nothing survives it,
  /// which is why UI-13 makes the user type the scope's name first.
  Future<Result<void>> hardDelete(String id);
}
