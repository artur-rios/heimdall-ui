import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/health/data/health_repository_impl.dart';

void main() {
  late Dio dio;

  ApiHealthRepository repositoryAnswering(_Answer answer) {
    dio.httpClientAdapter = _StubAdapter(answer);

    return ApiHealthRepository(HealthCheckClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAReachableApi_WhenPinged_ThenItsAnswerIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
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
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.ping();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test('GivenAHealthyApi_WhenDetailed_ThenEveryServiceIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'status': 'Healthy',
            'services': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Database', 'status': 'Healthy'},
              <String, dynamic>{'name': 'Mail', 'status': 'Healthy'},
            ],
          },
        },
      ),
    );

    // When
    final result = await repository.detailed();

    // Then
    expect(result.valueOrNull?.status, 'Healthy');
    expect(result.valueOrNull?.services, hasLength(2));
    expect(result.valueOrNull?.unhealthy, isEmpty);
  });

  // A 503 is the API reporting itself unhealthy, not failing to answer — the
  // report is in the body and is what an operator came for.
  test('GivenAnUnhealthyApi_WhenDetailed_ThenTheReportIsStillRead', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 503,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>[],
          'data': <String, dynamic>{
            'status': 'Unhealthy',
            'services': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Database', 'status': 'Healthy'},
              <String, dynamic>{'name': 'Mail', 'status': 'Unhealthy'},
            ],
          },
        },
      ),
    );

    // When
    final result = await repository.detailed();

    // Then
    expect(result.valueOrNull?.status, 'Unhealthy');
    expect(result.valueOrNull?.unhealthy.single.name, 'Mail');
  });

  // A Scope Admin is refused the detailed report, which the screen treats as
  // an expected answer rather than a fault.
  test('GivenAScopeAdmin_WhenDetailed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 403,
        body: <String, dynamic>{'success': false, 'errors': <String>[]},
      ),
    );

    // When
    final result = await repository.detailed();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
  });

  test('GivenNoConnection_WhenDetailed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.detailed();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test('GivenAnUnnamedService_WhenDetailed_ThenItStillHasALabel', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'status': 'Healthy',
            'services': <Map<String, dynamic>>[<String, dynamic>{}],
          },
        },
      ),
    );

    // When
    final result = await repository.detailed();

    // Then
    expect(result.valueOrNull?.services.single.name, 'Unnamed service');
    expect(result.valueOrNull?.services.single.status, 'Unknown');
  });
}

class _Answer {
  const _Answer({required this.status, this.body});

  final int status;
  final Map<String, dynamic>? body;
}

/// Answers from memory, so no test reaches the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._answer);

  final _Answer _answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_answer.status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No route to host',
      );
    }

    return ResponseBody.fromString(
      jsonEncode(_answer.body),
      _answer.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
