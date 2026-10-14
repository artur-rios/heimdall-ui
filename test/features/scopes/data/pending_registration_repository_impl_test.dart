import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/data/pending_registration_repository_impl.dart';

void main() {
  late Dio dio;
  late _StubAdapter adapter;

  ApiPendingRegistrationRepository repositoryAnswering(_Answer answer) {
    adapter = _StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiPendingRegistrationRepository(ScopeClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAPage_WhenListed_ThenRegistrationsAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'r1',
              'name': 'Ada Lovelace',
              'email': 'ada@example.com',
              'createdAt': '2026-10-13T09:00:00Z',
              'expiresAt': '2026-10-14T09:00:00Z',
              'attemptsLeft': 7,
              'expired': true,
            },
          ],
          'pageNumber': 1,
          'pageSize': 20,
          'totalItems': 1,
          'totalPages': 1,
        },
      ),
    );

    // When
    final result = await repository.list('s1');

    // Then
    final item = result.valueOrNull!.items.single;
    expect(item.email, 'ada@example.com');
    expect(item.attemptsLeft, 7);
    expect(item.expired, isTrue);
    expect(item.expiresAt, DateTime.utc(2026, 10, 14, 9));
  });

  test(
    'GivenARegistration_WhenDiscarded_ThenItsScopeAndIdAreAddressed',
    () async {
      // Given
      final repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{'id': 'r1'},
          },
        ),
      );

      // When
      final result = await repository.discard('s1', 'r1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.paths.single, '/api/scopes/s1/pending-registrations/r1');
      expect(adapter.methods.single, 'DELETE');
    },
  );

  test(
    'GivenAGoneRegistration_WhenDiscarded_ThenTheFailureIsNotFound',
    () async {
      // Given — AF-35d
      final repository = repositoryAnswering(
        const _Answer(
          status: 404,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Pending registration not found.'],
          },
        ),
      );

      // When
      final result = await repository.discard('s1', 'r1');

      // Then
      expect(result.failureOrNull!.kind, FailureKind.notFound);
      expect(result.failureOrNull!.errors, <String>[
        'Pending registration not found.',
      ]);
    },
  );
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

  /// The query parameters it was asked for, so a test can assert which filters
  /// actually travelled.
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  /// The request paths and methods it was sent, so a test can assert which
  /// record was addressed and how.
  final List<String> paths = <String>[];
  final List<String> methods = <String>[];

  /// The request bodies it was sent, as JSON, so a test can assert which
  /// fields actually travelled.
  final List<Object?> bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(options.queryParameters);
    paths.add(options.path);
    methods.add(options.method);
    bodies.add(
      options.data == null ? null : jsonDecode(jsonEncode(options.data)),
    );

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
