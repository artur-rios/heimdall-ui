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
}

/// Overridden at start-up with the client-backed implementation, and in tests
/// with a fake.
final Provider<ApplicationRepository> applicationRepositoryProvider =
    Provider<ApplicationRepository>(
      (ref) => throw UnimplementedError(
        'applicationRepositoryProvider must be overridden',
      ),
    );
