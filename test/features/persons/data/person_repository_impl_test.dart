import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/data/person_repository_impl.dart';

void main() {
  late Dio dio;
  late _StubAdapter adapter;

  ApiPersonRepository repositoryAnswering(_Answer answer) {
    adapter = _StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiPersonRepository(PersonClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAPersonResponse_WhenReadById_ThenThePersonIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'person-1',
            'name': 'Ada',
            'email': 'ada@example.com',
            'role': 2,
            'emailVerified': true,
            'isDeleted': false,
            'ownedScopeIds': <String>['scope-1'],
          },
        },
      ),
    );

    // When
    final result = await repository.getById('person-1');

    // Then
    expect(result.valueOrNull?.name, 'Ada');
    expect(result.valueOrNull?.role, Role.scopeAdmin);
    expect(result.valueOrNull?.ownedScopeIds, <String>['scope-1']);
  });

  test(
    'GivenAnUnknownRoleValue_WhenReadById_ThenTheRoleFallsBackToUser',
    () async {
      // Given
      final repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{'id': 'person-1', 'role': 99},
          },
        ),
      );

      // When
      final result = await repository.getById('person-1');

      // Then
      expect(result.valueOrNull?.role, Role.user);
    },
  );

  // AF-08e — the one refusal that ends the session has to arrive as itself.
  test('GivenAMissingPerson_WhenReadById_ThenNotFoundIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 404,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Person not found.'],
        },
      ),
    );

    // When
    final result = await repository.getById('gone');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.notFound);
  });

  test(
    'GivenAnUpdatedPerson_WhenUpdated_ThenTheNewValuesAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{
              'id': 'person-1',
              'name': 'Ada L',
              'email': 'ada.l@example.com',
              'role': 3,
              'emailVerified': false,
            },
          },
        ),
      );

      // When
      final result = await repository.update(
        id: 'person-1',
        name: 'Ada L',
        email: 'ada.l@example.com',
      );

      // Then
      expect(result.valueOrNull?.email, 'ada.l@example.com');
      expect(result.valueOrNull?.emailVerified, isFalse);
    },
  );

  test('GivenAnOrdinaryEdit_WhenUpdated_ThenTheRoleIsSentAsNull', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'id': 'person-1'},
        },
      ),
    );

    // When
    await repository.update(id: 'person-1', name: 'Ada', email: 'a@b.c');

    // Then
    expect(adapter.requests.single['roleId'], isNull);
  });

  // AF-08b — the API's own strings are what the screen shows.
  test('GivenARejectedUpdate_WhenUpdated_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Email is already taken.'],
        },
      ),
    );

    // When
    final result = await repository.update(
      id: 'person-1',
      name: 'Ada',
      email: 'taken@example.com',
    );

    // Then
    expect(result.failureOrNull?.errors, <String>['Email is already taken.']);
  });

  test('GivenNoConnection_WhenReadById_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.getById('person-1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test(
    'GivenAScopeAdminListing_WhenRead_ThenTheSummariesAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'person-1',
                'name': 'Ada',
                'email': 'ada@example.com',
              },
            ],
            'pageNumber': 1,
            'pageSize': 50,
            'totalItems': 1,
            'totalPages': 1,
          },
        ),
      );

      // When
      final result = await repository.listScopeAdmins(pageSize: 50);

      // Then
      expect(result.valueOrNull?.items.single.name, 'Ada');
      expect(result.valueOrNull?.items.single.email, 'ada@example.com');
    },
  );

  // AF-14c depends on this filter reaching the API, because the exclusion is
  // the API's to apply — the client does not know who owns what.
  test('GivenAnExcludedScope_WhenListed_ThenTheFilterIsSent', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
        },
      ),
    );

    // When
    await repository.listScopeAdmins(excludeOwnersOfScopeId: 'scope-1');

    // Then
    expect(adapter.queries.single['ExcludeOwnersOfScopeId'], 'scope-1');
  });

  // An empty filter is no filter: sent, it would ask the API to match the
  // empty string rather than to stop narrowing.
  test('GivenABlankQuery_WhenListed_ThenNoFilterIsSent', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
        },
      ),
    );

    // When
    await repository.listScopeAdmins(name: '   ', excludeOwnersOfScopeId: '');

    // Then
    expect(adapter.queries.single.containsKey('Name'), isFalse);
    expect(
      adapter.queries.single.containsKey('ExcludeOwnersOfScopeId'),
      isFalse,
    );
  });

  test('GivenNoConnection_WhenListed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.listScopeAdmins();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test('GivenASecondFactor_WhenReadById_ThenItIsCarried', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'person-1',
            'name': 'Ada',
            'email': 'ada@example.com',
            'role': 2,
            'twoFactorEnabled': true,
          },
        },
      ),
    );

    // When
    final result = await repository.getById('person-1');

    // Then
    expect(result.valueOrNull?.twoFactorEnabled, isTrue);
  });
}

/// What the stub answers with. A [status] of zero stands for a connection that
/// never got as far as a response.
class _Answer {
  const _Answer({required this.status, this.body});

  final int status;
  final Map<String, dynamic>? body;
}

/// Answers from memory, so no test reaches the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._answer);

  final _Answer _answer;

  /// The bodies it was asked to send, so a test can assert which field a value
  /// travelled in.
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];

  /// The query strings it was asked for, so a test can assert which filters
  /// reached the API and which were left off.
  final List<Map<String, String>> queries = <Map<String, String>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(options.uri.queryParameters);

    if (requestStream != null) {
      final bytes = <int>[];

      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }

      if (bytes.isNotEmpty) {
        if (jsonDecode(utf8.decode(bytes)) case final Map<String, dynamic> b) {
          requests.add(b);
        }
      }
    }

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
