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
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<ScopePermissionRepository> scopePermissionRepositoryProvider =
    Provider<ScopePermissionRepository>(
      (ref) => throw UnimplementedError(
        'scopePermissionRepositoryProvider must be overridden',
      ),
    );
