import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/health_repository.dart';

/// [HealthRepository] over the generated client.
class ApiHealthRepository implements HealthRepository {
  const ApiHealthRepository(this._client);

  final HealthCheckClient _client;

  @override
  Future<Result<String>> ping() async {
    try {
      final response = await _client.healthCheckHelloWorld();

      if (response.success != true) {
        return FailureResult<String>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      // Whatever it said is the answer; that it answered is the point.
      return Success<String>(response.data ?? 'The API answered.');
    } on DioException catch (error) {
      return FailureResult<String>(failureFromDioException(error));
    }
  }
}
