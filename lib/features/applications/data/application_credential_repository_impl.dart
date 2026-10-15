import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/application_credential.dart';
import '../domain/application_credential_repository.dart';

/// [ApplicationCredentialRepository] over the generated client.
class ApiApplicationCredentialRepository
    implements ApplicationCredentialRepository {
  const ApiApplicationCredentialRepository(this._client);

  final ApplicationCredentialClient _client;

  @override
  Future<Result<List<ApplicationCredential>>> list(
    String scopeId,
    String applicationId,
  ) async {
    try {
      final response = await _client.applicationCredentialList(
        scopeId: scopeId,
        id: applicationId,
      );

      if (response.success != true) {
        return FailureResult<List<ApplicationCredential>>(
          _refusal(response.errors),
        );
      }

      return Success<List<ApplicationCredential>>(
        (response.data?.credentials ?? const <ApplicationCredentialOutput>[])
            .map(
              (o) => ApplicationCredential(
                id: o.id ?? '',
                live: o.live ?? false,
                createdAt: o.createdAt,
                expiresAt: o.expiresAt,
                revokedAt: o.revokedAt,
                lastUsedAt: o.lastUsedAt,
              ),
            )
            .toList(growable: false),
      );
    } on DioException catch (error) {
      return FailureResult<List<ApplicationCredential>>(
        failureFromDioException(error),
      );
    }
  }

  @override
  Future<Result<IssuedCredential>> issue(
    String scopeId,
    String applicationId, {
    DateTime? expiresAt,
  }) async {
    try {
      final response = await _client.applicationCredentialIssue(
        scopeId: scopeId,
        id: applicationId,
        body: IssueApplicationCredentialCommand(expiresAt: expiresAt),
      );

      if (response.success != true) {
        return FailureResult<IssuedCredential>(_refusal(response.errors));
      }

      final data = response.data;

      if (data == null || data.secret == null || data.id == null) {
        return const FailureResult<IssuedCredential>(_incompleteResponse);
      }

      return Success<IssuedCredential>(
        IssuedCredential(
          id: data.id!,
          secret: data.secret!,
          createdAt: data.createdAt,
          expiresAt: data.expiresAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<IssuedCredential>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> revoke(
    String scopeId,
    String applicationId,
    String credentialId,
  ) async {
    try {
      final response = await _client.applicationCredentialRevoke(
        scopeId: scopeId,
        id: applicationId,
        credentialId: credentialId,
      );

      return response.success == true
          ? const Success<void>(null)
          : FailureResult<void>(_refusal(response.errors));
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }
}

Failure _refusal(List<String>? errors) =>
    Failure(kind: FailureKind.validation, errors: errors ?? const <String>[]);

const Failure _incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);
