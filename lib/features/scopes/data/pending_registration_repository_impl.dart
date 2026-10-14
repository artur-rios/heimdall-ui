import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/pending_registration.dart';
import '../domain/pending_registration_repository.dart';

/// [PendingRegistrationRepository] over the generated client.
class ApiPendingRegistrationRepository
    implements PendingRegistrationRepository {
  const ApiPendingRegistrationRepository(this._client);

  final ScopeClient _client;

  @override
  Future<Result<Page<PendingRegistration>>> list(
    String scopeId, {
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.scopeListPendingRegistrations(
        id: scopeId,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<PendingRegistration>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <PendingRegistrationOutput>[])
          .map(_fromOutput)
          .toList(growable: false);

      return Success<Page<PendingRegistration>>(
        Page<PendingRegistration>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Page<PendingRegistration>>(
        failureFromDioException(error),
      );
    }
  }

  @override
  Future<Result<void>> discard(String scopeId, String registrationId) async {
    try {
      final response = await _client.scopeDiscardPendingRegistration(
        id: scopeId,
        registrationId: registrationId,
      );

      return response.success == true
          ? const Success<void>(null)
          : FailureResult<void>(
              Failure(
                kind: FailureKind.validation,
                errors: response.errors ?? const <String>[],
              ),
            );
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }
}

PendingRegistration _fromOutput(PendingRegistrationOutput o) =>
    PendingRegistration(
      id: o.id ?? '',
      name: o.name ?? '',
      email: o.email ?? '',
      createdAt: o.createdAt,
      expiresAt: o.expiresAt,
      attemptsLeft: o.attemptsLeft ?? 0,
      expired: o.expired ?? false,
    );
