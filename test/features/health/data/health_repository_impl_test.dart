import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/health/data/health_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;

  ApiHealthRepository repositoryAnswering(StubAnswer answer) {
    dio.httpClientAdapter = StubAdapter(answer);

    return ApiHealthRepository(HealthCheckClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAReachableApi_WhenPinged_ThenItsAnswerIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': 'Hello, world!',
        },
      ),
    );

    // When
    final result = await repository.ping();

    // Then
    expect(result.valueOrNull, 'Hello, world!');
  });

  test('GivenNoConnection_WhenPinged_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.ping();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });
}
