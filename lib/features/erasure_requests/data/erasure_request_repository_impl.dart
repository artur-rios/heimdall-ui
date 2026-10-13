import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/erasure_request_repository.dart';
import '../domain/outstanding_erasure.dart';

/// [ErasureRequestRepository] over the generated client.
class ApiErasureRequestRepository implements ErasureRequestRepository {
  const ApiErasureRequestRepository(this._client);

  final AuthClient _client;

  @override
  Future<Result<Page<OutstandingErasure>>> list({
    bool overdueOnly = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.authListErasureRequests(
        overdueOnly: overdueOnly,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<OutstandingErasure>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <ErasureRequestOutput>[])
          .map(_fromOutput)
          .toList(growable: false);

      return Success<Page<OutstandingErasure>>(
        Page<OutstandingErasure>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Page<OutstandingErasure>>(
        failureFromDioException(error),
      );
    }
  }

  @override
  Future<Result<ReconciliationOutcome>> reapply(List<String> subjectIds) async {
    try {
      final response = await _client.authReapplyErasures(
        body: ReapplyErasuresCommand(subjectIds: subjectIds),
      );

      if (response.success != true) {
        return FailureResult<ReconciliationOutcome>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<ReconciliationOutcome>(_incompleteResponse);
      }

      return Success<ReconciliationOutcome>(
        ReconciliationOutcome(
          anonymised: data.anonymised ?? 0,
          alreadyAnonymised: data.alreadyAnonymised ?? 0,
          notFound: data.notFound ?? const <String>[],
        ),
      );
    } on DioException catch (error) {
      return FailureResult<ReconciliationOutcome>(
        failureFromDioException(error),
      );
    }
  }
}

const Failure _incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);

OutstandingErasure _fromOutput(ErasureRequestOutput o) => OutstandingErasure(
  subjectId: o.subjectId ?? '',
  isGoogleUser: o.isGoogleUser ?? false,
  requestedAt: o.requestedAt,
  dueAt: o.dueAt,
  overdue: o.overdue ?? false,
  blockedReason: (o.blockedReason?.trim().isEmpty ?? true)
      ? null
      : o.blockedReason,
);
