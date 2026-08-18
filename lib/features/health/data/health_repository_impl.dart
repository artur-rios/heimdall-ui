import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/health.dart';
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

  @override
  Future<Result<Health>> detailed() async {
    try {
      final response = await _client.healthCheckDetailed();

      return _healthFrom(response);
    } on DioException catch (error) {
      // A `503` is the API reporting itself unhealthy rather than failing to
      // answer, and its body carries the report — so it is read rather than
      // turned into a bare failure.
      if (error.response?.statusCode == 503) {
        final body = error.response?.data;

        if (body is Map<String, dynamic>) {
          return _healthFrom(HealthCheckOutputDataOutput.fromJson(body));
        }
      }

      // A `403` for a Scope Admin arrives here, and its kind is what lets the
      // screen call it an expected refusal rather than a fault.
      return FailureResult<Health>(failureFromDioException(error));
    }
  }

  Result<Health> _healthFrom(HealthCheckOutputDataOutput response) {
    final data = response.data;

    if (data == null) {
      return FailureResult<Health>(
        Failure(
          kind: FailureKind.unknown,
          errors: response.errors ?? const <String>[],
        ),
      );
    }

    return Success<Health>(
      Health(
        status: data.status ?? 'Unknown',
        services: (data.services ?? const <ServiceHealthOutput>[])
            .map(
              (service) => ServiceHealth(
                name: service.name ?? 'Unnamed service',
                status: service.status ?? 'Unknown',
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
