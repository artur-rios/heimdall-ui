import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../auth/domain/session.dart';
import '../domain/audit_entry.dart';
import '../domain/audit_log_repository.dart';

/// [AuditLogRepository] over the generated client.
class ApiAuditLogRepository implements AuditLogRepository {
  const ApiAuditLogRepository(this._client);

  final AuditClient _client;

  @override
  Future<Result<Page<AuditEntry>>> list({
    AuditLogFilter filter = const AuditLogFilter(),
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final bounds = switch ((filter.firstDay, filter.lastDay)) {
      (final DateTime first, final DateTime last) => auditBoundsFor(
        first,
        last,
      ),
      _ => null,
    };

    try {
      final response = await _client.auditList(
        from: bounds?.from,
        to: bounds?.to,
        actorId: filter.actorId,
        action: filter.action,
        targetId: filter.targetId,
        succeeded: filter.succeeded,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<AuditEntry>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <AuditLogEntryOutput>[])
          .map(_fromOutput)
          .toList(growable: false);

      return Success<Page<AuditEntry>>(
        Page<AuditEntry>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Page<AuditEntry>>(failureFromDioException(error));
    }
  }
}

AuditEntry _fromOutput(AuditLogEntryOutput o) => AuditEntry(
  id: o.id ?? '',
  recordedAt: o.recordedAt,
  actorId: o.actorId,
  actorRole: o.actorRole == null ? null : roleFromValue(o.actorRole!),
  action: o.action ?? '',
  targetId: o.targetId,
  succeeded: o.succeeded ?? false,
  failureReason: (o.failureReason?.trim().isEmpty ?? true)
      ? null
      : o.failureReason,
);
