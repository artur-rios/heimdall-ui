import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'audit_entry.dart';

/// The audit-trail read UI-34 depends on. System Admin only; the API refuses
/// anybody else (UC-48 AF-48b).
abstract interface class AuditLogRepository {
  /// One page of entries matching [filter], newest first.
  Future<Result<Page<AuditEntry>>> list({
    AuditLogFilter filter = const AuditLogFilter(),
    int pageNumber = 1,
    int pageSize = 20,
  });
}

final Provider<AuditLogRepository> auditLogRepositoryProvider =
    Provider<AuditLogRepository>(
      (ref) => throw UnimplementedError(
        'auditLogRepositoryProvider must be overridden',
      ),
    );
