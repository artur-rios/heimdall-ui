import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/data/application_repository_impl.dart';

void main() {
  late Dio dio;
  late _StubAdapter adapter;

  ApiApplicationRepository repositoryAnswering(_Answer answer) {
    adapter = _StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiApplicationRepository(ApplicationClient(dio));
  }

  const onePage = _Answer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'app-1',
          'name': 'Billing',
          'scopeId': 'scope-1',
          'ownerId': 'person-1',
          'isDeleted': false,
        },
      ],
      'pageNumber': 1,
      'pageSize': 20,
      'totalItems': 1,
      'totalPages': 1,
    },
  );

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAPage_WhenListed_ThenTheApplicationsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(onePage);

    // When
    final result = await repository.list(scopeId: 'scope-1');

    // Then
    expect(result.valueOrNull?.items.single.name, 'Billing');
    expect(result.valueOrNull?.items.single.ownerId, 'person-1');
  });

  test('GivenAName_WhenListed_ThenItTravelsAsAQueryParameter', () async {
    // Given
    final repository = repositoryAnswering(onePage);

    // When
    await repository.list(
      scopeId: 'scope-1',
      name: 'Billing',
      includeDeleted: true,
      pageNumber: 2,
    );

    // Then
    expect(adapter.queries.single, containsPair('Name', 'Billing'));
    expect(adapter.queries.single, containsPair('IncludeDeleted', true));
    expect(adapter.queries.single, containsPair('PageNumber', 2));
  });

  test('GivenABlankName_WhenListed_ThenNoNameIsSent', () async {
    // Given
    final repository = repositoryAnswering(onePage);

    // When
    await repository.list(scopeId: 'scope-1', name: '   ');

    // Then
    expect(adapter.queries.single.containsKey('Name'), isFalse);
  });

  test(
    'GivenAnApplicationWithNoOwner_WhenListed_ThenTheOwnerIsEmpty',
    () async {
      // Given
      final repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'app-1', 'name': 'Billing'},
            ],
            'totalItems': 1,
          },
        ),
      );

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.valueOrNull?.items.single.ownerId, '');
    },
  );

  // AF-20b — the API refused, and its own strings are what the screen shows.
  test('GivenARefusedListing_WhenListed_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Page size is too large.'],
        },
      ),
    );

    // When
    final result = await repository.list(scopeId: 'scope-1');

    // Then
    expect(result.failureOrNull?.errors, <String>['Page size is too large.']);
  });

  // AF-20c — a scope this admin does not own.
  test('GivenAForbiddenScope_WhenListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 403,
        body: <String, dynamic>{'success': false, 'errors': <String>[]},
      ),
    );

    // When
    final result = await repository.list(scopeId: 'scope-1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
  });

  test('GivenNoConnection_WhenListed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.list(scopeId: 'scope-1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
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

  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(options.queryParameters);

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
