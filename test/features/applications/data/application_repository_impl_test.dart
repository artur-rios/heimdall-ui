import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/data/application_repository_impl.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiApplicationRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiApplicationRepository(ApplicationClient(dio));
  }

  const onePage = StubAnswer(
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
        const StubAnswer(
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
      const StubAnswer(
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
      const StubAnswer(
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
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.list(scopeId: 'scope-1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  const application = <String, dynamic>{
    'id': 'app-1',
    'name': 'Billing',
    'ownerId': 'person-1',
    'scopeId': 'scope-1',
    'isDeleted': true,
    'createdAt': '2026-01-02T03:04:05.000Z',
    'updatedAt': '2026-02-03T04:05:06.000Z',
  };

  const refused = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['An application with this name already exists.'],
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

  const emptyData = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': true, 'data': <String, dynamic>{}},
  );

  const fullData = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': true, 'data': application},
  );

  const noConnection = StubAnswer(status: 0);

  group('list', () {
    test('GivenAPaddedOwner_WhenListed_ThenItTravelsTrimmed', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list(scopeId: 'scope-1', ownerId: ' person-1 ');

      // Then
      expect(adapter.paths.single, '/api/scopes/scope-1/applications');
      expect(adapter.queries.single, containsPair('OwnerId', 'person-1'));
      expect(adapter.queries.single, containsPair('IncludeDeleted', false));
      expect(adapter.queries.single, containsPair('PageSize', 20));
    });

    test('GivenABlankOwner_WhenListed_ThenNoOwnerIsSent', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list(scopeId: 'scope-1', ownerId: '  ');

      // Then
      expect(adapter.queries.single.containsKey('OwnerId'), isFalse);
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
              'data': <Map<String, dynamic>>[application, application],
            },
          ),
        );

        // When
        final result = await repository.list(
          scopeId: 'scope-1',
          pageNumber: 3,
          pageSize: 5,
        );

        // Then
        final page = result.valueOrNull!;
        expect(page.pageNumber, 3);
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
  });

  group('create', () {
    Future<Result<Application>> createIn(ApiApplicationRepository repository) =>
        repository.create(
          scopeId: 'scope-1',
          name: 'Billing',
          ownerId: 'person-1',
        );

    test('GivenAnApplication_WhenCreated_ThenItIsPostedToItsScope', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await createIn(repository);

      // Then
      expect(adapter.methods.single, 'POST');
      expect(adapter.paths.single, '/api/scopes/scope-1/applications');
      expect(adapter.requests.single, <String, dynamic>{
        'name': 'Billing',
        'ownerId': 'person-1',
      });
    });

    test(
      'GivenACreatedApplication_WhenCreated_ThenTheAnswerIsMapped',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'id': 'app-9',
                'name': 'Invoices',
                'ownerId': 'person-2',
                'scopeId': 'scope-2',
                'createdAt': '2026-01-02T03:04:05.000Z',
              },
            },
          ),
        );

        // When
        final result = await createIn(repository);

        // Then
        final created = result.valueOrNull!;
        expect(created.id, 'app-9');
        expect(created.name, 'Invoices');
        expect(created.ownerId, 'person-2');
        expect(created.scopeId, 'scope-2');
        expect(created.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
        expect(created.isDeleted, isFalse);
      },
    );

    test(
      'GivenAnAnswerWithNoFields_WhenCreated_ThenWhatWasSentFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(emptyData);

        // When
        final result = await createIn(repository);

        // Then
        final created = result.valueOrNull!;
        expect(created.id, '');
        expect(created.name, 'Billing');
        expect(created.ownerId, 'person-1');
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

    // AF-21b — a duplicate name, in the API's own words.
    test('GivenADuplicateName_WhenCreated_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await createIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'An application with this name already exists.',
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
    test('GivenAnApplication_WhenRead_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'app-1');

      // Then
      expect(adapter.methods.single, 'GET');
      expect(adapter.paths.single, '/api/scopes/scope-1/applications/app-1');
      expect(adapter.queries.single, containsPair('includeDeleted', true));
      final read = result.valueOrNull!;
      expect(read.id, 'app-1');
      expect(read.name, 'Billing');
      expect(read.ownerId, 'person-1');
      expect(read.scopeId, 'scope-1');
      expect(read.isDeleted, isTrue);
      expect(read.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(read.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
    });

    test(
      'GivenIncludeDeletedOff_WhenRead_ThenItTravelsAsAQueryParameter',
      () async {
        // Given
        final repository = repositoryAnswering(fullData);

        // When
        await repository.getById(
          scopeId: 'scope-1',
          id: 'app-1',
          includeDeleted: false,
        );

        // Then
        expect(adapter.queries.single, containsPair('includeDeleted', false));
      },
    );

    test(
      'GivenAnApplicationWithNoFields_WhenRead_ThenTheDefaultsAreUsed',
      () async {
        // Given
        final repository = repositoryAnswering(emptyData);

        // When
        final result = await repository.getById(
          scopeId: 'scope-1',
          id: 'app-1',
        );

        // Then
        final read = result.valueOrNull!;
        expect(read.id, '');
        expect(read.name, '');
        expect(read.ownerId, '');
        expect(read.scopeId, isNull);
        expect(read.isDeleted, isFalse);
        expect(read.createdAt, isNull);
        expect(read.updatedAt, isNull);
      },
    );

    test('GivenNoData_WhenRead_ThenAnIncompleteAnswerIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'app-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
    });

    test('GivenARefusal_WhenRead_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'app-1');

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
        final result = await repository.getById(
          scopeId: 'scope-1',
          id: 'app-1',
        );

        // Then
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    // AF-22a — the application is gone.
    test('GivenAMissingApplication_WhenRead_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{'success': false, 'errors': <String>[]},
        ),
      );

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'app-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    // AF-22b — a scope this admin does not own.
    test('GivenAForbiddenScope_WhenRead_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 403,
          body: <String, dynamic>{'success': false, 'errors': <String>[]},
        ),
      );

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'app-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test('GivenNoConnection_WhenRead_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.getById(scopeId: 'scope-1', id: 'app-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('update', () {
    Future<Result<Application>> updateIn(ApiApplicationRepository repository) =>
        repository.update(
          scopeId: 'scope-1',
          id: 'app-1',
          name: 'Billing',
          ownerId: 'person-1',
        );

    test('GivenAChange_WhenUpdated_ThenItIsPutOnTheApplication', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await updateIn(repository);

      // Then
      expect(adapter.methods.single, 'PUT');
      expect(adapter.paths.single, '/api/scopes/scope-1/applications/app-1');
      expect(adapter.requests.single, <String, dynamic>{
        'name': 'Billing',
        'ownerId': 'person-1',
      });
    });

    test(
      'GivenAnUpdatedApplication_WhenUpdated_ThenItIsMappedAsNotDeleted',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'id': 'app-7',
                'name': 'Invoices',
                'ownerId': 'person-2',
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
        expect(updated.id, 'app-7');
        expect(updated.name, 'Invoices');
        expect(updated.ownerId, 'person-2');
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
        final repository = repositoryAnswering(emptyData);

        // When
        final result = await updateIn(repository);

        // Then
        final updated = result.valueOrNull!;
        expect(updated.id, 'app-1');
        expect(updated.name, 'Billing');
        expect(updated.ownerId, 'person-1');
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

    // AF-22c — a duplicate name, or an owner of another scope.
    test('GivenADuplicateName_WhenUpdated_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await updateIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'An application with this name already exists.',
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
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'app-1');

      // Then
      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/api/scopes/scope-1/applications/app-1');
      expect(result.isSuccess, isTrue);
    });

    // AF-23b — the API refuses an application it will not delete.
    test('GivenARefusal_WhenDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'app-1');

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
        final result = await repository.delete(scopeId: 'scope-1', id: 'app-1');

        // Then
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.delete(scopeId: 'scope-1', id: 'app-1');

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
          id: 'app-1',
        );

        // Then
        expect(adapter.methods.single, 'DELETE');
        expect(
          adapter.paths.single,
          '/api/scopes/scope-1/applications/app-1/hard',
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
        id: 'app-1',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, hasLength(1));
    });

    test('GivenNoConnection_WhenHardDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.hardDelete(
        scopeId: 'scope-1',
        id: 'app-1',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });
}
