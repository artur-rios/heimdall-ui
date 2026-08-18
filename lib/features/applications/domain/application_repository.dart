import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'application.dart';

/// The application operations the interface depends on.
abstract interface class ApplicationRepository {
  /// Reads one page of a scope's applications.
  Future<Result<Page<Application>>> list({
    required String scopeId,
    String? name,
    String? ownerId,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Creates an application within a scope.
  ///
  /// Whether [ownerId] names a person of that scope is the API's question —
  /// AF-21c is what its answer looks like when they are not.
  Future<Result<Application>> create({
    required String scopeId,
    required String name,
    required String ownerId,
  });

  /// Reads one application.
  ///
  /// [includeDeleted] is on by default for the detail screen: AF-22d shows a
  /// logically deleted application read-only, and it cannot do that if the API
  /// is asked to pretend it is gone.
  Future<Result<Application>> getById({
    required String scopeId,
    required String id,
    bool includeDeleted = true,
  });

  /// Updates an application's name and owner.
  Future<Result<Application>> update({
    required String scopeId,
    required String id,
    required String name,
    required String ownerId,
  });

  /// Logically deletes an application. The record is kept and the API can
  /// restore it.
  Future<Result<void>> delete({required String scopeId, required String id});

  /// Permanently deletes an application. Only a System Admin may, which is why
  /// UI-23 shows the control to nobody else.
  Future<Result<void>> hardDelete({
    required String scopeId,
    required String id,
  });
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<ApplicationRepository> applicationRepositoryProvider =
    Provider<ApplicationRepository>(
      (ref) => throw UnimplementedError(
        'applicationRepositoryProvider must be overridden',
      ),
    );
