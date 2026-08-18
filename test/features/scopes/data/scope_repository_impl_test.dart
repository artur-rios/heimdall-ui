import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/data/scope_repository_impl.dart';

void main() {
  late Dio dio;
  late _StubAdapter adapter;

  ApiScopeRepository repositoryAnswering(_Answer answer) {
    adapter = _StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiScopeRepository(ScopeClient(dio));
  }

  const onePage = _Answer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'scope-1',
          'name': 'Acme',
          'description': 'The first tenant',
          'googleSignInEnabled': true,
          'isDeleted': false,
          'ownerIds': <String>['person-1', 'person-2'],
        },
      ],
      'pageNumber': 2,
      'pageSize': 20,
      'totalItems': 41,
      'totalPages': 3,
    },
  );

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAPageOfScopes_WhenListed_ThenTheItemsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(onePage);

    // When
    final result = await repository.list();

    // Then
    expect(result.valueOrNull?.items.single.name, 'Acme');
    expect(result.valueOrNull?.items.single.ownerCount, 2);
  });

  test('GivenAPageOfScopes_WhenListed_ThenThePagingIsReturned', () async {
    // Given
    final repository = repositoryAnswering(onePage);

    // When
    final result = await repository.list();

    // Then
    expect(result.valueOrNull?.pageNumber, 2);
    expect(result.valueOrNull?.totalPages, 3);
    expect(result.valueOrNull?.hasNextPage, isTrue);
  });

  test('GivenAName_WhenListed_ThenItTravelsAsAQueryParameter', () async {
    // Given
    final repository = repositoryAnswering(onePage);

    // When
    await repository.list(name: 'Acme', includeDeleted: true, pageNumber: 3);

    // Then
    expect(adapter.queries.single, containsPair('Name', 'Acme'));
    expect(adapter.queries.single, containsPair('IncludeDeleted', true));
    expect(adapter.queries.single, containsPair('PageNumber', 3));
  });

  // An empty search is no search: sending it would ask the API to match the
  // empty string rather than to stop filtering.
  test('GivenABlankName_WhenListed_ThenNoNameIsSent', () async {
    // Given
    final repository = repositoryAnswering(onePage);

    // When
    await repository.list(name: '   ');

    // Then
    expect(adapter.queries.single.containsKey('Name'), isFalse);
  });

  test('GivenAnEmptyPage_WhenListed_ThenNoItemsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
          'pageNumber': 1,
          'totalItems': 0,
          'totalPages': 1,
        },
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.valueOrNull?.items, isEmpty);
  });

  // AF-10b — the API refused, and its own strings are what the screen shows.
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
    final result = await repository.list();

    // Then
    expect(result.failureOrNull?.errors, <String>['Page size is too large.']);
  });

  // AF-10b — a transport failure keeps its own kind, which is what offers the
  // retry rather than an error panel with nothing in it.
  test('GivenNoConnection_WhenListed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test('GivenAForbiddenListing_WhenListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 403,
        body: <String, dynamic>{'success': false, 'errors': <String>[]},
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
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

  /// The query parameters it was asked for, so a test can assert which filters
  /// actually travelled.
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
