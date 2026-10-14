import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'pending_registration.dart';

/// The pending self-registration reads and discards UI-35 depends on.
abstract interface class PendingRegistrationRepository {
  /// One page of the scope's pending registrations.
  Future<Result<Page<PendingRegistration>>> list(
    String scopeId, {
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Removes one pending registration so its holder may register again.
  Future<Result<void>> discard(String scopeId, String registrationId);
}

final Provider<PendingRegistrationRepository>
pendingRegistrationRepositoryProvider = Provider<PendingRegistrationRepository>(
  (ref) => throw UnimplementedError(
    'pendingRegistrationRepositoryProvider must be overridden',
  ),
);
