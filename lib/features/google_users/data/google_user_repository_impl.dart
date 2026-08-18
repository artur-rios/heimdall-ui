import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/google_user_repository.dart';

/// [GoogleUserRepository] over the generated client.
class ApiGoogleUserRepository implements GoogleUserRepository {
  const ApiGoogleUserRepository(this._client);

  final GoogleUserClient _client;

  @override
  Future<Result<int>> countIn(String scopeId) async {
    try {
      final response = await _client.googleUserList(
        scopeId: scopeId,
        pageNumber: 1,
        // One item is enough: the count comes from the envelope's own total,
        // not from how many rows came back.
        pageSize: 1,
      );

      if (response.success != true) {
        return FailureResult<int>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return Success<int>(response.totalItems ?? response.data?.length ?? 0);
    } on DioException catch (error) {
      return FailureResult<int>(failureFromDioException(error));
    }
  }
}
