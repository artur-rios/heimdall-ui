import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/health/data/health_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiHealthRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

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

  test('GivenAPing_WhenSent_ThenItIsAGetOfTheHealthCheck', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{'success': true, 'data': 'Hello, world!'},
      ),
    );

    // When
    await repository.ping();

    // Then
    expect(adapter.methods.single, 'GET');
    expect(adapter.paths.single, '/api/healthcheck');
    expect(adapter.bodies.single, isNull);
  });

  // That it answered is the point, so an answer without words still counts.
  test(
    'GivenAnAnswerWithoutData_WhenPinged_ThenAPlainAnswerIsReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{'success': true, 'errors': <String>[]},
        ),
      );

      // When
      final result = await repository.ping();

      // Then
      expect(result.valueOrNull, 'The API answered.');
    },
  );

  test('GivenARefusalWithinA200_WhenPinged_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['The API is shutting down.'],
        },
      ),
    );

    // When
    final result = await repository.ping();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.validation);
    expect(result.failureOrNull?.errors, <String>['The API is shutting down.']);
  });

  test(
    'GivenARefusalWithoutReason_WhenPinged_ThenNoErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{'success': false},
        ),
      );

      // When
      final result = await repository.ping();

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, isEmpty);
    },
  );

  test('GivenAServerError_WhenPinged_ThenServerFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 503,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Service unavailable.'],
        },
      ),
    );

    // When
    final result = await repository.ping();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.server);
    expect(result.failureOrNull?.errors, <String>['Service unavailable.']);
  });
}
