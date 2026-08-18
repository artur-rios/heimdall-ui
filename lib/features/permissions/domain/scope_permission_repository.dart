import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'scope_permission.dart';

/// The scope permission operations the interface depends on.
abstract interface class ScopePermissionRepository {
  /// Reads one page of a scope's permissions.
  Future<Result<Page<ScopePermission>>> list({
    required String scopeId,
    String? name,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Creates a permission within a scope.
  Future<Result<ScopePermission>> create({
    required String scopeId,
    required String name,
    required String description,
    required bool includeAsJwtClaim,
  });

  /// Reads one permission.
  ///
  /// [includeDeleted] is on by default for the detail screen: AF-26d shows a
  /// logically deleted permission read-only, and it cannot do that if the API
  /// is asked to pretend it is gone.
  Future<Result<ScopePermission>> getById({
    required String scopeId,
    required String id,
    bool includeDeleted = true,
  });

  /// Updates a permission's name, description, and claim flag.
  Future<Result<ScopePermission>> update({
    required String scopeId,
    required String id,
    required String name,
    required String description,
    required bool includeAsJwtClaim,
  });
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<ScopePermissionRepository> scopePermissionRepositoryProvider =
    Provider<ScopePermissionRepository>(
      (ref) => throw UnimplementedError(
        'scopePermissionRepositoryProvider must be overridden',
      ),
    );
