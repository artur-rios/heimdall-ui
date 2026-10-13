import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'outstanding_erasure.dart';

/// The erasure-request operations UI-32 depends on. System Admin only; the
/// API refuses anybody else.
abstract interface class ErasureRequestRepository {
  /// One page of outstanding requests, soonest deadline first (UC-43).
  Future<Result<Page<OutstandingErasure>>> list({
    bool overdueOnly = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Re-applies erasure to [subjectIds] after a restore. Safe to repeat.
  Future<Result<ReconciliationOutcome>> reapply(List<String> subjectIds);
}

final Provider<ErasureRequestRepository> erasureRequestRepositoryProvider =
    Provider<ErasureRequestRepository>(
      (ref) => throw UnimplementedError(
        'erasureRequestRepositoryProvider must be overridden',
      ),
    );
