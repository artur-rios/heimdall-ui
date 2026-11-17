import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/permissions/data/scope_permission_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiScopePermissionRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiScopePermissionRepository(ScopePermissionClient(dio));
  }

  const permission = <String, dynamic>{
    'id': 'perm-1',
    'name': 'invoices.read',
    'description': 'Reads invoices',
    'includeAsJwtClaim': true,
    'scopeId': 'scope-1',
    'isDeleted': true,
    'createdAt': '2026-01-02T03:04:05.000Z',
    'updatedAt': '2026-02-03T04:05:06.000Z',
  };

  const onePage = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[permission],
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
      'errors': <String>['A permission with this name already exists.'],
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

  const acknowledged = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': true, 'errors': <String>[]},
  );

  const forbidden = StubAnswer(
    status: 403,
    body: <String, dynamic>{'success': false, 'errors': <String>[]},
  );

  const noConnection = StubAnswer(status: 0);

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  group('list', () {
    test('GivenAPage_WhenListed_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      final page = result.valueOrNull!;
      final item = page.items.single;
      expect(item.id, 'perm-1');
      expect(item.name, 'invoices.read');
      expect(item.description, 'Reads invoices');
      expect(item.includeAsJwtClaim, isTrue);
      expect(item.scopeId, 'scope-1');
      expect(item.isDeleted, isTrue);
      expect(item.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(item.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(page.pageNumber, 2);
      expect(page.pageSize, 10);
      expect(page.totalItems, 11);
      expect(page.totalPages, 2);
    });

    test(
      'GivenFiltersAndPaging_WhenListed_ThenTheyTravelAsQueryParameters',
      () async {
        // Given
        final repository = repositoryAnswering(onePage);

        // When
        await repository.list(
          scopeId: 'scope-1',
          name: '  invoices  ',
          includeDeleted: true,
          pageNumber: 3,
          pageSize: 50,
        );

        // Then
        expect(adapter.methods.single, 'GET');
        expect(adapter.paths.single, '/api/scopes/scope-1/permissions');
        expect(adapter.queries.single, containsPair('Name', 'invoices'));
        expect(adapter.queries.single, containsPair('IncludeDeleted', true));
        expect(adapter.queries.single, containsPair('PageNumber', 3));
        expect(adapter.queries.single, containsPair('PageSize', 50));
      },
    );

    test('GivenNoArguments_WhenListed_ThenTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list(scopeId: 'scope-1');

      // Then
      expect(adapter.queries.single.containsKey('Name'), isFalse);
      expect(adapter.queries.single, containsPair('IncludeDeleted', false));
      expect(adapter.queries.single, containsPair('PageNumber', 1));
      expect(adapter.queries.single, containsPair('PageSize', 20));
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
      'GivenAPermissionWithNoFields_WhenListed_ThenTheDefaultsAreUsed',
      () async {
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
        final item = result.valueOrNull!.items.single;
        expect(item.id, '');
        expect(item.name, '');
        expect(item.description, '');
        expect(item.includeAsJwtClaim, isFalse);
        expect(item.scopeId, isNull);
        expect(item.isDeleted, isFalse);
        expect(item.createdAt, isNull);
        expect(item.updatedAt, isNull);
      },
    );

    test(
      'GivenAnEnvelopeWithoutPaging_WhenListed_ThenTheRequestAndItemsFillIt',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <Map<String, dynamic>>[permission, permission],
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
      expect(result.valueOrNull?.totalItems, 0);
    });

    test('GivenARefusedListing_WhenListed_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'A permission with this name already exists.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenListed_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.list(scopeId: 'scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    // AF-24c — a scope this admin does not own.
    test('GivenAForbiddenScope_WhenListed_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(forbidden);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    // AF-24b — the API could not be reached.
    test('GivenNoConnection_WhenListed_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.list(scopeId: 'scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('create', () {
    Future<Result<dynamic>> createIn(ApiScopePermissionRepository repository) =>
        repository.create(
          scopeId: 'scope-1',
          name: 'invoices.read',
          description: 'Reads invoices',
          includeAsJwtClaim: true,
        );

    test('GivenAPermission_WhenCreated_ThenItIsPostedToItsScope', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{'success': true, 'data': permission},
        ),
      );

      // When
      await createIn(repository);

      // Then
      expect(adapter.methods.single, 'POST');
      expect(adapter.paths.single, '/api/scopes/scope-1/permissions');
      expect(adapter.requests.single, <String, dynamic>{
        'name': 'invoices.read',
        'description': 'Reads invoices',
        'includeAsJwtClaim': true,
      });
    });

    test('GivenACreatedPermission_WhenCreated_ThenTheAnswerIsMapped', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'id': 'perm-9',
              'name': 'invoices.write',
              'description': 'Writes invoices',
              'includeAsJwtClaim': false,
              'scopeId': 'scope-2',
              'createdAt': '2026-01-02T03:04:05.000Z',
            },
          },
        ),
      );

      // When
      final result = await repository.create(
        scopeId: 'scope-1',
        name: 'invoices.read',
        description: 'Reads invoices',
        includeAsJwtClaim: true,
      );

      // Then
      final created = result.valueOrNull!;
      expect(created.id, 'perm-9');
      expect(created.name, 'invoices.write');
      expect(created.description, 'Writes invoices');
      expect(created.includeAsJwtClaim, isFalse);
      expect(created.scopeId, 'scope-2');
      expect(created.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(created.isDeleted, isFalse);
    });

    test(
      'GivenAnAnswerWithNoFields_WhenCreated_ThenWhatWasSentFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{},
            },
          ),
        );

        // When
        final result = await repository.create(
          scopeId: 'scope-1',
          name: 'invoices.read',
          description: 'Reads invoices',
          includeAsJwtClaim: true,
        );

        // Then
        final created = result.valueOrNull!;
        expect(created.id, '');
        expect(created.name, 'invoices.read');
        expect(created.description, 'Reads invoices');
        expect(created.includeAsJwtClaim, isTrue);
        expect(created.scopeId, 'scope-1');
        expect(created.createdAt, isNull);
      },
    );

    test('GivenNoData_WhenCreated_ThenAnIncompleteAnswerIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await createIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
      expect(result.failureOrNull?.errors, <String>[
        'The API returned an incomplete response.',
      ]);
    });

    // AF-25b — a name already used in this scope.
    test('GivenADuplicateName_WhenCreated_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await createIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'A permission with this name already exists.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenCreated_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await createIn(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenCreated_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await createIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('getById', () {
    test(
      'GivenAPermission_WhenRead_ThenItIsAskedForIncludingDeletedOnes',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{'success': true, 'data': permission},
          ),
        );

        // When
        final result = await repository.getById(
          scopeId: 'scope-1',
          id: 'perm-1',
        );

        // Then
        expect(adapter.methods.single, 'GET');
        expect(adapter.paths.single, '/api/scopes/scope-1/permissions/perm-1');
        expect(adapter.queries.single, containsPair('includeDeleted', true));
        expect(result.valueOrNull?.name, 'invoices.read');
        expect(result.valueOrNull?.isDeleted, isTrue);
      },
    );

    test(
      'GivenIncludeDeletedOff_WhenRead_ThenItTravelsAsAQueryParameter',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{'success': true, 'data': permission},
          ),
        );

        // When
        await repository.getById(
          scopeId: 'scope-1',
          id: 'perm-1',
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
      final result = await repository.getById(scopeId: 'scope-1', id: 'p');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
    });

    test('GivenARefusal_WhenRead_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'p');

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
        final result = await repository.getById(scopeId: 'scope-1', id: 'p');

        // Then
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    // AF-26a — the permission is gone.
    test('GivenAMissingPermission_WhenRead_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{'success': false, 'errors': <String>[]},
        ),
      );

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'p');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    // AF-26b — a scope this admin does not own.
    test('GivenAForbiddenScope_WhenRead_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(forbidden);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'p');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test('GivenNoConnection_WhenRead_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'p');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('update', () {
    Future<Result<dynamic>> updateIn(ApiScopePermissionRepository repository) =>
        repository.update(
          scopeId: 'scope-1',
          id: 'perm-1',
          name: 'invoices.read',
          description: 'Reads invoices',
          includeAsJwtClaim: false,
        );

    test('GivenAChange_WhenUpdated_ThenItIsPutOnThePermission', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{'success': true, 'data': permission},
        ),
      );

      // When
      await updateIn(repository);

      // Then
      expect(adapter.methods.single, 'PUT');
      expect(adapter.paths.single, '/api/scopes/scope-1/permissions/perm-1');
      expect(adapter.requests.single, <String, dynamic>{
        'name': 'invoices.read',
        'description': 'Reads invoices',
        'includeAsJwtClaim': false,
      });
    });

    test(
      'GivenAnUpdatedPermission_WhenUpdated_ThenTheAnswerIsMappedAsNotDeleted',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'id': 'perm-7',
                'name': 'invoices.write',
                'description': 'Writes invoices',
                'includeAsJwtClaim': true,
                'scopeId': 'scope-2',
                'createdAt': '2026-01-02T03:04:05.000Z',
                'updatedAt': '2026-02-03T04:05:06.000Z',
              },
            },
          ),
        );

        // When
        final result = await updateIn(repository);

        // Then
        final updated = result.valueOrNull!;
        expect(updated.id, 'perm-7');
        expect(updated.name, 'invoices.write');
        expect(updated.description, 'Writes invoices');
        expect(updated.includeAsJwtClaim, isTrue);
        expect(updated.scopeId, 'scope-2');
        expect(updated.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
        expect(updated.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
        expect(updated.isDeleted, isFalse);
      },
    );

    test(
      'GivenAnAnswerWithNoFields_WhenUpdated_ThenWhatWasSentFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{},
            },
          ),
        );

        // When
        final result = await updateIn(repository);

        // Then
        final updated = result.valueOrNull!;
        expect(updated.id, 'perm-1');
        expect(updated.name, 'invoices.read');
        expect(updated.description, 'Reads invoices');
        expect(updated.includeAsJwtClaim, isFalse);
        expect(updated.scopeId, 'scope-1');
        expect(updated.updatedAt, isNull);
      },
    );

    test('GivenNoData_WhenUpdated_ThenAnIncompleteAnswerIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await updateIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
    });

    // AF-26c — a duplicate name.
    test('GivenADuplicateName_WhenUpdated_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await updateIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'A permission with this name already exists.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenUpdated_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await updateIn(repository);

        // Then
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenUpdated_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await updateIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('delete', () {
    test('GivenAnAcknowledgement_WhenDeleted_ThenItSucceeds', () async {
      // Given
      final repository = repositoryAnswering(acknowledged);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'perm-1');

      // Then
      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/api/scopes/scope-1/permissions/perm-1');
      expect(result.isSuccess, isTrue);
    });

    // AF-27b — the API refuses a permission it will not delete.
    test('GivenARefusal_WhenDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'perm-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, hasLength(1));
    });

    test(
      'GivenARefusalWithoutErrors_WhenDeleted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.delete(
          scopeId: 'scope-1',
          id: 'perm-1',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'perm-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('hardDelete', () {
    test(
      'GivenAnAcknowledgement_WhenHardDeleted_ThenTheHardEndpointIsUsed',
      () async {
        // Given
        final repository = repositoryAnswering(acknowledged);

        // When
        final result = await repository.hardDelete(
          scopeId: 'scope-1',
          id: 'perm-1',
        );

        // Then
        expect(adapter.methods.single, 'DELETE');
        expect(
          adapter.paths.single,
          '/api/scopes/scope-1/permissions/perm-1/hard',
        );
        expect(result.isSuccess, isTrue);
      },
    );

    test('GivenARefusal_WhenHardDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.hardDelete(
        scopeId: 'scope-1',
        id: 'perm-1',
      );

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
          id: 'perm-1',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.forbidden);
      },
    );

    test('GivenNoConnection_WhenHardDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.hardDelete(
        scopeId: 'scope-1',
        id: 'perm-1',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });
}
