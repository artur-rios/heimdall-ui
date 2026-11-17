import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/google_users/data/google_user_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiGoogleUserRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiGoogleUserRepository(GoogleUserClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test(
    'GivenAScopeWithGoogleUsers_WhenCounted_ThenTheTotalIsReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'google-1'},
            ],
            'totalItems': 12,
            'totalPages': 12,
          },
        ),
      );

      // When
      final result = await repository.countIn('scope-1');

      // Then
      expect(result.valueOrNull, 12);
    },
  );

  // The count is the envelope's own total, not how many rows came back.
  test('GivenAScopeWithGoogleUsers_WhenCounted_ThenOneRowIsAskedFor', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
          'totalItems': 12,
        },
      ),
    );

    // When
    await repository.countIn('scope-1');

    // Then
    expect(adapter.queries.single, containsPair('PageSize', 1));
  });

  test('GivenAScopeWithNoGoogleUsers_WhenCounted_ThenZeroIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
          'totalItems': 0,
        },
      ),
    );

    // When
    final result = await repository.countIn('scope-1');

    // Then
    expect(result.valueOrNull, 0);
  });

  test('GivenARefusedListing_WhenCounted_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['That scope is not yours.'],
        },
      ),
    );

    // When
    final result = await repository.countIn('scope-1');

    // Then
    expect(result.failureOrNull?.errors, <String>['That scope is not yours.']);
  });

  test('GivenNoConnection_WhenCounted_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.countIn('scope-1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  const googleUser = <String, dynamic>{
    'id': 'google-1',
    'googleId': 'g-123',
    'name': 'Ada Lovelace',
    'email': 'ada@example.com',
    'emailVerified': false,
    'profilePictureUrl': 'https://example.invalid/ada.png',
    'isDeleted': true,
    'scopeId': 'scope-1',
    'createdAt': '2026-01-02T03:04:05.000Z',
    'updatedAt': '2026-02-03T04:05:06.000Z',
  };

  const onePage = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[googleUser],
      'pageNumber': 2,
      'pageSize': 10,
      'totalItems': 11,
      'totalPages': 2,
    },
  );

  const refused = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['This Google user cannot be deleted.'],
    },
  );

  const refusedWithoutReason = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': false},
  );

  const noData = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': true, 'errors': <String>[]},
  );

  const forbidden = StubAnswer(
    status: 403,
    body: <String, dynamic>{'success': false, 'errors': <String>[]},
  );

  const noConnection = StubAnswer(status: 0);

  group('countIn', () {
    test('GivenNoTotal_WhenCounted_ThenTheRowsAreCounted', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[googleUser],
          },
        ),
      );

      // When
      final result = await repository.countIn('scope-1');

      // Then
      expect(result.valueOrNull, 1);
    });

    test('GivenNoTotalAndNoData_WhenCounted_ThenZeroIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.countIn('scope-1');

      // Then
      expect(result.valueOrNull, 0);
    });

    test(
      'GivenARefusalWithoutErrors_WhenCounted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.countIn('scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );
  });

  group('list', () {
    test('GivenAPage_WhenListed_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      final page = result.valueOrNull!;
      final user = page.items.single;
      expect(user.id, 'google-1');
      expect(user.googleId, 'g-123');
      expect(user.name, 'Ada Lovelace');
      expect(user.email, 'ada@example.com');
      expect(user.emailVerified, isFalse);
      expect(user.profilePictureUrl, 'https://example.invalid/ada.png');
      expect(user.isDeleted, isTrue);
      expect(user.scopeId, 'scope-1');
      expect(user.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(user.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(page.pageNumber, 2);
      expect(page.pageSize, 10);
      expect(page.totalItems, 11);
      expect(page.totalPages, 2);
    });

    test('GivenFiltersAndPaging_WhenListed_ThenTheyTravelTrimmed', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list(
        scopeId: 'scope-1',
        name: ' Ada ',
        email: ' ada@example.com ',
        includeDeleted: true,
        pageNumber: 3,
        pageSize: 50,
      );

      // Then
      expect(adapter.methods.single, 'GET');
      expect(adapter.paths.single, '/api/scopes/scope-1/google-users');
      expect(adapter.queries.single, containsPair('Name', 'Ada'));
      expect(adapter.queries.single, containsPair('Email', 'ada@example.com'));
      expect(adapter.queries.single, containsPair('IncludeDeleted', true));
      expect(adapter.queries.single, containsPair('PageNumber', 3));
      expect(adapter.queries.single, containsPair('PageSize', 50));
    });

    test('GivenBlankFilters_WhenListed_ThenOnlyTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list(scopeId: 'scope-1', name: ' ', email: '');

      // Then
      expect(adapter.queries.single.containsKey('Name'), isFalse);
      expect(adapter.queries.single.containsKey('Email'), isFalse);
      expect(adapter.queries.single, containsPair('IncludeDeleted', false));
      expect(adapter.queries.single, containsPair('PageNumber', 1));
      expect(adapter.queries.single, containsPair('PageSize', 20));
    });

    test('GivenAUserWithNoFields_WhenListed_ThenTheDefaultsAreUsed', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[<String, dynamic>{}],
          },
        ),
      );

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      final user = result.valueOrNull!.items.single;
      expect(user.id, '');
      expect(user.name, '');
      expect(user.email, '');
      expect(user.googleId, isNull);
      expect(user.emailVerified, isTrue);
      expect(user.profilePictureUrl, isNull);
      expect(user.isDeleted, isFalse);
      expect(user.scopeId, isNull);
      expect(user.createdAt, isNull);
    });

    test(
      'GivenAnEnvelopeWithoutPaging_WhenListed_ThenTheRequestFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <Map<String, dynamic>>[googleUser, googleUser],
            },
          ),
        );

        // When
        final result = await repository.list(
          scopeId: 'scope-1',
          pageNumber: 4,
          pageSize: 5,
        );

        // Then
        final page = result.valueOrNull!;
        expect(page.pageNumber, 4);
        expect(page.pageSize, 5);
        expect(page.totalItems, 2);
        expect(page.totalPages, 1);
      },
    );

    test('GivenNoData_WhenListed_ThenThePageIsEmpty', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.valueOrNull?.items, isEmpty);
    });

    test('GivenARefusal_WhenListed_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, hasLength(1));
    });

    test(
      'GivenARefusalWithoutErrors_WhenListed_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.list(scopeId: 'scope-1');

        // Then
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    // AF-28c — a scope this admin does not own.
    test('GivenAForbiddenScope_WhenListed_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(forbidden);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    // AF-28b — the API could not be reached.
    test('GivenNoConnection_WhenListed_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('getById', () {
    test('GivenAUser_WhenRead_ThenItIsAskedForIncludingDeletedOnes', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{'success': true, 'data': googleUser},
        ),
      );

      // When
      final result = await repository.getById(
        scopeId: 'scope-1',
        id: 'google-1',
      );

      // Then
      expect(adapter.methods.single, 'GET');
      expect(adapter.paths.single, '/api/scopes/scope-1/google-users/google-1');
      expect(adapter.queries.single, containsPair('includeDeleted', true));
      expect(result.valueOrNull?.email, 'ada@example.com');
      expect(result.valueOrNull?.isDeleted, isTrue);
    });

    test(
      'GivenIncludeDeletedOff_WhenRead_ThenItTravelsAsAQueryParameter',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{'success': true, 'data': googleUser},
          ),
        );

        // When
        await repository.getById(
          scopeId: 'scope-1',
          id: 'google-1',
          includeDeleted: false,
        );

        // Then
        expect(adapter.queries.single, containsPair('includeDeleted', false));
      },
    );

    test('GivenNoData_WhenRead_ThenAnIncompleteAnswerIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'g');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
      expect(result.failureOrNull?.errors, <String>[
        'The API returned an incomplete response.',
      ]);
    });

    test('GivenARefusal_WhenRead_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'g');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, hasLength(1));
    });

    test(
      'GivenARefusalWithoutErrors_WhenRead_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.getById(scopeId: 'scope-1', id: 'g');

        // Then
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenAMissingUser_WhenRead_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{'success': false, 'errors': <String>[]},
        ),
      );

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'g');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    test('GivenNoConnection_WhenRead_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'g');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('delete', () {
    test('GivenAnAcknowledgement_WhenDeleted_ThenItSucceeds', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'g-1');

      // Then
      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/api/scopes/scope-1/google-users/g-1');
      expect(result.isSuccess, isTrue);
    });

    // AF-29b — the API refuses a record it will not delete.
    test('GivenARefusal_WhenDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'g-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'This Google user cannot be deleted.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenDeleted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.delete(scopeId: 'scope-1', id: 'g-1');

        // Then
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'g-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('hardDelete', () {
    test(
      'GivenAnAcknowledgement_WhenHardDeleted_ThenTheHardEndpointIsUsed',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.hardDelete(
          scopeId: 'scope-1',
          id: 'g-1',
        );

        // Then
        expect(adapter.methods.single, 'DELETE');
        expect(
          adapter.paths.single,
          '/api/scopes/scope-1/google-users/g-1/hard',
        );
        expect(result.isSuccess, isTrue);
      },
    );

    test('GivenARefusal_WhenHardDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.hardDelete(scopeId: 'scope-1', id: 'g-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, hasLength(1));
    });

    test(
      'GivenAForbiddenScope_WhenHardDeleted_ThenForbiddenIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(forbidden);

        // When
        final result = await repository.hardDelete(
          scopeId: 'scope-1',
          id: 'g-1',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.forbidden);
      },
    );

    test('GivenNoConnection_WhenHardDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.hardDelete(scopeId: 'scope-1', id: 'g-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });
}
