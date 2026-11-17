import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/data/scope_repository_impl.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiScopeRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiScopeRepository(ScopeClient(dio));
  }

  const onePage = StubAnswer(
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

  const updated = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <String, dynamic>{
        'id': 'scope-1',
        'name': 'Acme Ltd',
        'description': 'The first tenant',
        'googleSignInEnabled': false,
        'ownerIds': <String>['person-1'],
      },
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
      const StubAnswer(
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
      const StubAnswer(
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
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test('GivenAForbiddenListing_WhenListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 403,
        body: <String, dynamic>{'success': false, 'errors': <String>[]},
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
  });

  test('GivenPrivacySettings_WhenRead_ThenTheyAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'scope-1',
            'name': 'Acme',
            'description': 'The first tenant',
            'defaultLegalBasis': 2,
            'privacyNoticeUri': 'https://acme.example/privacy',
          },
        },
      ),
    );

    // When
    final result = await repository.getById('scope-1');

    // Then
    expect(result.valueOrNull?.defaultLegalBasis, 2);
    expect(
      result.valueOrNull?.privacyNoticeUri,
      'https://acme.example/privacy',
    );
  });

  // The API replaces every field it accepts, so the privacy settings must
  // travel with an update or they are cleared.
  test('GivenPrivacySettings_WhenUpdated_ThenTheyTravelInTheBody', () async {
    // Given
    final repository = repositoryAnswering(updated);

    // When
    await repository.update(
      id: 'scope-1',
      name: 'Acme Ltd',
      description: 'The first tenant',
      defaultLegalBasis: 2,
      privacyNoticeUri: 'https://acme.example/privacy',
    );

    // Then
    expect(adapter.bodies.single, <String, dynamic>{
      'name': 'Acme Ltd',
      'description': 'The first tenant',
      'defaultLegalBasis': 2,
      'privacyNoticeUri': 'https://acme.example/privacy',
    });
  });

  // The update's output does not carry the privacy settings, and the API has
  // just stored exactly what was sent.
  test('GivenPrivacySettings_WhenUpdated_ThenTheResultKeepsThem', () async {
    // Given
    final repository = repositoryAnswering(updated);

    // When
    final result = await repository.update(
      id: 'scope-1',
      name: 'Acme Ltd',
      description: 'The first tenant',
      defaultLegalBasis: 2,
      privacyNoticeUri: 'https://acme.example/privacy',
    );

    // Then
    expect(result.valueOrNull?.name, 'Acme Ltd');
    expect(result.valueOrNull?.defaultLegalBasis, 2);
    expect(
      result.valueOrNull?.privacyNoticeUri,
      'https://acme.example/privacy',
    );
  });

  const signUpOpened = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <String, dynamic>{
        'id': 'scope-1',
        'name': 'Acme',
        'description': 'The first tenant',
        'googleSignInEnabled': false,
        'selfRegistrationEnabled': true,
        'emailVerificationUrl': 'https://acme.example/verify-email',
        'passwordResetUrl': null,
        'ownerIds': <String>['person-1'],
      },
    },
  );

  test('GivenScopeSettings_WhenRead_ThenTheyAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'scope-1',
            'name': 'Acme',
            'description': 'The first tenant',
            'selfRegistrationEnabled': true,
            'emailVerificationUrl': 'https://acme.example/verify-email',
            'passwordResetUrl': 'https://acme.example/password-reset',
          },
        },
      ),
    );

    // When
    final result = await repository.getById('scope-1');

    // Then
    final scope = result.valueOrNull!;
    expect(scope.selfRegistrationEnabled, isTrue);
    expect(scope.emailVerificationUrl, 'https://acme.example/verify-email');
    expect(scope.passwordResetUrl, 'https://acme.example/password-reset');
  });

  test('GivenAnEmptyLinkFromTheApi_WhenRead_ThenItIsNoLink', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'scope-1',
            'name': 'Acme',
            'description': '',
            'emailVerificationUrl': '',
          },
        },
      ),
    );

    // When
    final result = await repository.getById('scope-1');

    // Then
    expect(result.valueOrNull!.emailVerificationUrl, isNull);
  });

  test('GivenSelfRegistration_WhenOpened_ThenTheBodySaysSo', () async {
    // Given
    final repository = repositoryAnswering(signUpOpened);

    // When
    await repository.setSelfRegistration(id: 'scope-1', enabled: true);

    // Then
    expect(adapter.bodies.single, <String, dynamic>{'enabled': true});
  });

  test('GivenSelfRegistration_WhenOpened_ThenTheScopeIsReturned', () async {
    // Given
    final repository = repositoryAnswering(signUpOpened);

    // When
    final result = await repository.setSelfRegistration(
      id: 'scope-1',
      enabled: true,
    );

    // Then
    expect(result.valueOrNull!.selfRegistrationEnabled, isTrue);
    expect(
      result.valueOrNull!.emailVerificationUrl,
      'https://acme.example/verify-email',
    );
  });

  test(
    'GivenARefusedSelfRegistration_WhenSet_ThenApiErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 403,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['You do not own this scope.'],
          },
        ),
      );

      // When
      final result = await repository.setSelfRegistration(
        id: 'scope-1',
        enabled: true,
      );

      // Then
      expect(result.failureOrNull!.kind, FailureKind.forbidden);
      expect(result.failureOrNull!.errors, <String>[
        'You do not own this scope.',
      ]);
    },
  );

  test('GivenEmailLinks_WhenSet_ThenBothTravelInTheBody', () async {
    // Given
    final repository = repositoryAnswering(signUpOpened);

    // When
    await repository.setEmailLinks(
      id: 'scope-1',
      emailVerificationUrl: 'https://acme.example/verify-email',
      passwordResetUrl: null,
    );

    // Then
    expect(adapter.bodies.single, <String, dynamic>{
      'emailVerificationUrl': 'https://acme.example/verify-email',
      'passwordResetUrl': null,
    });
  });

  test('GivenRefusedEmailLinks_WhenSet_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 400,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['The email link must be an absolute URL.'],
        },
      ),
    );

    // When
    final result = await repository.setEmailLinks(
      id: 'scope-1',
      emailVerificationUrl: 'nope',
      passwordResetUrl: null,
    );

    // Then
    expect(result.failureOrNull!.kind, FailureKind.validation);
    expect(result.failureOrNull!.errors, <String>[
      'The email link must be an absolute URL.',
    ]);
  });

  test(
    'GivenNoConnection_WhenEmailLinksSet_ThenNetworkFailureIsReturned',
    () async {
      // Given
      final repository = repositoryAnswering(const StubAnswer(status: 0));

      // When
      final result = await repository.setEmailLinks(
        id: 'scope-1',
        emailVerificationUrl: null,
        passwordResetUrl: null,
      );

      // Then
      expect(result.failureOrNull!.kind, FailureKind.network);
    },
  );

  const everyField = <String, dynamic>{
    'id': 'scope-9',
    'name': 'Globex',
    'description': 'The second tenant',
    'googleSignInEnabled': true,
    'selfRegistrationEnabled': true,
    'emailVerificationUrl': 'https://globex.example/verify-email',
    'passwordResetUrl': 'https://globex.example/password-reset',
    'defaultLegalBasis': 3,
    'privacyNoticeUri': 'https://globex.example/privacy',
    'isDeleted': true,
    'ownerIds': <String>['person-7', 'person-8'],
    'createdAt': '2026-01-02T03:04:05.000Z',
    'updatedAt': '2026-02-03T04:05:06.000Z',
  };

  const refused = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['A scope with this name already exists.'],
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
    body: <String, dynamic>{'success': true, 'data': everyField},
  );

  const blankLinks = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'id': 'scope-1',
        'emailVerificationUrl': '   ',
        'passwordResetUrl': '',
      },
    },
  );

  const notFound = StubAnswer(
    status: 404,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['Scope not found.'],
    },
  );

  const forbidden = StubAnswer(
    status: 403,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['You do not own this scope.'],
    },
  );

  const noConnection = StubAnswer(status: 0);

  const incomplete = <String>['The API returned an incomplete response.'];

  group('list', () {
    test('GivenNoArguments_WhenListed_ThenTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list();

      // Then
      expect(adapter.methods.single, 'GET');
      expect(adapter.paths.single, '/api/scopes');
      expect(adapter.queries.single, <String, dynamic>{
        'IncludeDeleted': false,
        'PageNumber': 1,
        'PageSize': 20,
      });
    });

    test('GivenAPaddedName_WhenListed_ThenItTravelsTrimmed', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list(name: '  Acme  ', pageSize: 50);

      // Then
      expect(adapter.queries.single, containsPair('Name', 'Acme'));
      expect(adapter.queries.single, containsPair('PageSize', 50));
    });

    test('GivenAnEmptyName_WhenListed_ThenNoNameIsSent', () async {
      // Given
      final repository = repositoryAnswering(onePage);

      // When
      await repository.list(name: '');

      // Then
      expect(adapter.queries.single.containsKey('Name'), isFalse);
    });

    test('GivenAScopeWithEveryField_WhenListed_ThenEachIsMapped', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[everyField],
            'pageNumber': 2,
            'pageSize': 10,
            'totalItems': 11,
            'totalPages': 2,
          },
        ),
      );

      // When
      final result = await repository.list();

      // Then
      final page = result.valueOrNull!;
      final scope = page.items.single;
      expect(scope.id, 'scope-9');
      expect(scope.name, 'Globex');
      expect(scope.description, 'The second tenant');
      expect(scope.googleSignInEnabled, isTrue);
      expect(scope.selfRegistrationEnabled, isTrue);
      expect(scope.emailVerificationUrl, 'https://globex.example/verify-email');
      expect(scope.passwordResetUrl, 'https://globex.example/password-reset');
      expect(scope.defaultLegalBasis, 3);
      expect(scope.privacyNoticeUri, 'https://globex.example/privacy');
      expect(scope.isDeleted, isTrue);
      expect(scope.ownerIds, <String>['person-7', 'person-8']);
      expect(scope.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(scope.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(page.pageNumber, 2);
      expect(page.pageSize, 10);
      expect(page.totalItems, 11);
      expect(page.totalPages, 2);
    });

    test('GivenAScopeWithNoFields_WhenListed_ThenTheDefaultsAreUsed', () async {
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
      final result = await repository.list();

      // Then
      final scope = result.valueOrNull!.items.single;
      expect(scope.id, '');
      expect(scope.name, '');
      expect(scope.description, '');
      expect(scope.googleSignInEnabled, isFalse);
      expect(scope.selfRegistrationEnabled, isFalse);
      expect(scope.emailVerificationUrl, isNull);
      expect(scope.passwordResetUrl, isNull);
      expect(scope.defaultLegalBasis, isNull);
      expect(scope.privacyNoticeUri, isNull);
      expect(scope.isDeleted, isFalse);
      expect(scope.ownerIds, isEmpty);
      expect(scope.createdAt, isNull);
      expect(scope.updatedAt, isNull);
    });

    test(
      'GivenAnEnvelopeWithoutPaging_WhenListed_ThenTheRequestAndItemsFillIt',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <Map<String, dynamic>>[everyField, everyField],
            },
          ),
        );

        // When
        final result = await repository.list(pageNumber: 4, pageSize: 5);

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
      final result = await repository.list();

      // Then
      expect(result.valueOrNull?.items, isEmpty);
      expect(result.valueOrNull?.totalItems, 0);
    });

    test(
      'GivenARefusalWithoutErrors_WhenListed_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.list();

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );
  });

  group('create', () {
    Future<Result<Scope>> createIn(ApiScopeRepository repository) =>
        repository.create(
          name: 'Acme',
          description: 'The first tenant',
          ownerIds: <String>['person-1', 'person-2'],
        );

    test('GivenAScope_WhenCreated_ThenItIsPostedWithItsOwners', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await createIn(repository);

      // Then
      expect(adapter.methods.single, 'POST');
      expect(adapter.paths.single, '/api/scopes');
      expect(adapter.requests.single, <String, dynamic>{
        'name': 'Acme',
        'description': 'The first tenant',
        'ownerIds': <String>['person-1', 'person-2'],
      });
    });

    test('GivenACreatedScope_WhenCreated_ThenTheAnswerIsMapped', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await createIn(repository);

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, 'scope-9');
      expect(scope.name, 'Globex');
      expect(scope.description, 'The second tenant');
      expect(scope.googleSignInEnabled, isTrue);
      expect(scope.selfRegistrationEnabled, isTrue);
      expect(scope.emailVerificationUrl, 'https://globex.example/verify-email');
      expect(scope.passwordResetUrl, 'https://globex.example/password-reset');
      expect(scope.ownerIds, <String>['person-7', 'person-8']);
      expect(scope.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    // The create output carries no `isDeleted` and no privacy settings: a
    // scope just created is neither deleted nor configured.
    test('GivenACreatedScope_WhenCreated_ThenItIsNotDeletedAndHasNoPrivacySettings', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await createIn(repository);

      // Then
      final scope = result.valueOrNull!;
      expect(scope.isDeleted, isFalse);
      expect(scope.defaultLegalBasis, isNull);
      expect(scope.privacyNoticeUri, isNull);
      expect(scope.updatedAt, isNull);
    });

    test(
      'GivenAnAnswerWithNoFields_WhenCreated_ThenWhatWasSentFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(emptyData);

        // When
        final result = await createIn(repository);

        // Then
        final scope = result.valueOrNull!;
        expect(scope.id, '');
        expect(scope.name, 'Acme');
        expect(scope.description, 'The first tenant');
        expect(scope.googleSignInEnabled, isFalse);
        expect(scope.selfRegistrationEnabled, isFalse);
        expect(scope.emailVerificationUrl, isNull);
        expect(scope.passwordResetUrl, isNull);
        expect(scope.ownerIds, <String>['person-1', 'person-2']);
        expect(scope.createdAt, isNull);
      },
    );

    test('GivenBlankLinks_WhenCreated_ThenThereAreNoLinks', () async {
      // Given
      final repository = repositoryAnswering(blankLinks);

      // When
      final result = await createIn(repository);

      // Then
      expect(result.valueOrNull!.emailVerificationUrl, isNull);
      expect(result.valueOrNull!.passwordResetUrl, isNull);
    });

    test('GivenNoData_WhenCreated_ThenAnIncompleteAnswerIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await createIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
      expect(result.failureOrNull?.errors, incomplete);
    });

    // AF-11b — a name already in use.
    test('GivenADuplicateName_WhenCreated_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await createIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'A scope with this name already exists.',
      ]);
    });

    // AF-11c — an owner who is not a Scope Admin, refused with a 400.
    test(
      'GivenAnOwnerWhoIsNoScopeAdmin_WhenCreated_ThenApiErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 400,
            body: <String, dynamic>{
              'success': false,
              'errors': <String>['Every owner must be a Scope Admin.'],
            },
          ),
        );

        // When
        final result = await createIn(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>[
          'Every owner must be a Scope Admin.',
        ]);
      },
    );

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
    test('GivenAnId_WhenRead_ThenItIsAskedForIncludingDeletedOnes', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await repository.getById('scope-1');

      // Then
      expect(adapter.methods.single, 'GET');
      expect(adapter.paths.single, '/api/scopes/scope-1');
      expect(adapter.queries.single, <String, dynamic>{'includeDeleted': true});
    });

    test('GivenDeletedOnesLeftOut_WhenRead_ThenTheQuerySaysSo', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await repository.getById('scope-1', includeDeleted: false);

      // Then
      expect(adapter.queries.single, <String, dynamic>{
        'includeDeleted': false,
      });
    });

    test('GivenAScopeWithEveryField_WhenRead_ThenEachIsMapped', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await repository.getById('scope-9');

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, 'scope-9');
      expect(scope.name, 'Globex');
      expect(scope.description, 'The second tenant');
      expect(scope.googleSignInEnabled, isTrue);
      expect(scope.selfRegistrationEnabled, isTrue);
      expect(scope.passwordResetUrl, 'https://globex.example/password-reset');
      expect(scope.isDeleted, isTrue);
      expect(scope.ownerIds, <String>['person-7', 'person-8']);
      expect(scope.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(scope.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
    });

    test('GivenAScopeWithNoFields_WhenRead_ThenTheDefaultsAreUsed', () async {
      // Given
      final repository = repositoryAnswering(emptyData);

      // When
      final result = await repository.getById('scope-1');

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, '');
      expect(scope.name, '');
      expect(scope.description, '');
      expect(scope.googleSignInEnabled, isFalse);
      expect(scope.selfRegistrationEnabled, isFalse);
      expect(scope.isDeleted, isFalse);
      expect(scope.ownerIds, isEmpty);
    });

    test('GivenNoData_WhenRead_ThenAnIncompleteAnswerIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.getById('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
      expect(result.failureOrNull?.errors, incomplete);
    });

    test('GivenARefusal_WhenRead_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.getById('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'A scope with this name already exists.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenRead_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.getById('scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    // AF-12a — the scope does not exist.
    test('GivenAMissingScope_WhenRead_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(notFound);

      // When
      final result = await repository.getById('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
      expect(result.failureOrNull?.errors, <String>['Scope not found.']);
    });

    // AF-12b — a scope this admin does not own.
    test('GivenAScopeNotOwned_WhenRead_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(forbidden);

      // When
      final result = await repository.getById('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
      expect(result.failureOrNull?.errors, <String>[
        'You do not own this scope.',
      ]);
    });

    test('GivenNoConnection_WhenRead_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.getById('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('update', () {
    Future<Result<Scope>> updateIn(
      ApiScopeRepository repository, {
      int? defaultLegalBasis = 2,
      String? privacyNoticeUri = 'https://acme.example/privacy',
    }) => repository.update(
      id: 'scope-1',
      name: 'Acme Ltd',
      description: 'The first tenant',
      defaultLegalBasis: defaultLegalBasis,
      privacyNoticeUri: privacyNoticeUri,
    );

    test('GivenAnUpdate_WhenSent_ThenItIsPutToTheScope', () async {
      // Given
      final repository = repositoryAnswering(updated);

      // When
      await updateIn(repository);

      // Then
      expect(adapter.methods.single, 'PUT');
      expect(adapter.paths.single, '/api/scopes/scope-1');
      expect(adapter.requests.single, <String, dynamic>{
        'name': 'Acme Ltd',
        'description': 'The first tenant',
        'defaultLegalBasis': 2,
        'privacyNoticeUri': 'https://acme.example/privacy',
      });
    });

    // Clearing the privacy settings is sending them empty.
    test(
      'GivenNoPrivacySettings_WhenUpdated_ThenTheyTravelAndReturnAsNull',
      () async {
        // Given
        final repository = repositoryAnswering(updated);

        // When
        final result = await updateIn(
          repository,
          defaultLegalBasis: null,
          privacyNoticeUri: null,
        );

        // Then
        expect(adapter.requests.single, <String, dynamic>{
          'name': 'Acme Ltd',
          'description': 'The first tenant',
          'defaultLegalBasis': null,
          'privacyNoticeUri': null,
        });
        expect(result.valueOrNull?.defaultLegalBasis, isNull);
        expect(result.valueOrNull?.privacyNoticeUri, isNull);
      },
    );

    test('GivenAnUpdatedScope_WhenUpdated_ThenTheAnswerIsMapped', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await updateIn(repository);

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, 'scope-9');
      expect(scope.name, 'Globex');
      expect(scope.description, 'The second tenant');
      expect(scope.googleSignInEnabled, isTrue);
      expect(scope.selfRegistrationEnabled, isTrue);
      expect(scope.emailVerificationUrl, 'https://globex.example/verify-email');
      expect(scope.passwordResetUrl, 'https://globex.example/password-reset');
      expect(scope.ownerIds, <String>['person-7', 'person-8']);
      expect(scope.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(scope.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
    });

    // The update output carries no `isDeleted`, and the privacy settings are
    // the ones sent, whatever the answer holds.
    test(
      'GivenAnUpdatedScope_WhenUpdated_ThenItIsNotDeletedAndKeepsWhatWasSent',
      () async {
        // Given
        final repository = repositoryAnswering(fullData);

        // When
        final result = await updateIn(repository);

        // Then
        final scope = result.valueOrNull!;
        expect(scope.isDeleted, isFalse);
        expect(scope.defaultLegalBasis, 2);
        expect(scope.privacyNoticeUri, 'https://acme.example/privacy');
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
        final scope = result.valueOrNull!;
        expect(scope.id, 'scope-1');
        expect(scope.name, 'Acme Ltd');
        expect(scope.description, 'The first tenant');
        expect(scope.googleSignInEnabled, isFalse);
        expect(scope.selfRegistrationEnabled, isFalse);
        expect(scope.emailVerificationUrl, isNull);
        expect(scope.passwordResetUrl, isNull);
        expect(scope.ownerIds, isEmpty);
        expect(scope.createdAt, isNull);
        expect(scope.updatedAt, isNull);
      },
    );

    test('GivenBlankLinks_WhenUpdated_ThenThereAreNoLinks', () async {
      // Given
      final repository = repositoryAnswering(blankLinks);

      // When
      final result = await updateIn(repository);

      // Then
      expect(result.valueOrNull!.emailVerificationUrl, isNull);
      expect(result.valueOrNull!.passwordResetUrl, isNull);
    });

    test('GivenNoData_WhenUpdated_ThenAnIncompleteAnswerIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await updateIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unknown);
      expect(result.failureOrNull?.errors, incomplete);
    });

    // AF-12c — a name already in use.
    test('GivenADuplicateName_WhenUpdated_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await updateIn(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'A scope with this name already exists.',
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
        expect(result.failureOrNull?.kind, FailureKind.validation);
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

  group('setGoogleSignIn', () {
    test('GivenGoogleSignIn_WhenEnabled_ThenItIsPutToTheScope', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await repository.setGoogleSignIn(id: 'scope-1', enabled: true);

      // Then
      expect(adapter.methods.single, 'PUT');
      expect(adapter.paths.single, '/api/scopes/scope-1/google-signin');
      expect(adapter.requests.single, <String, dynamic>{'enabled': true});
    });

    test('GivenGoogleSignIn_WhenDisabled_ThenTheBodySaysSo', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await repository.setGoogleSignIn(id: 'scope-1', enabled: false);

      // Then
      expect(adapter.requests.single, <String, dynamic>{'enabled': false});
    });

    test('GivenAnAnswer_WhenGoogleSignInSet_ThenItIsMapped', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await repository.setGoogleSignIn(
        id: 'scope-1',
        enabled: true,
      );

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, 'scope-9');
      expect(scope.name, 'Globex');
      expect(scope.description, 'The second tenant');
      expect(scope.googleSignInEnabled, isTrue);
      expect(scope.emailVerificationUrl, 'https://globex.example/verify-email');
      expect(scope.passwordResetUrl, 'https://globex.example/password-reset');
      expect(scope.ownerIds, <String>['person-7', 'person-8']);
      expect(scope.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(scope.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
    });

    // Its output carries no self-registration, privacy settings or
    // `isDeleted`; the controller keeps the ones it already knows.
    test(
      'GivenAnAnswer_WhenGoogleSignInSet_ThenWhatItLacksIsLeftAtItsDefault',
      () async {
        // Given
        final repository = repositoryAnswering(fullData);

        // When
        final result = await repository.setGoogleSignIn(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        final scope = result.valueOrNull!;
        expect(scope.selfRegistrationEnabled, isFalse);
        expect(scope.defaultLegalBasis, isNull);
        expect(scope.privacyNoticeUri, isNull);
        expect(scope.isDeleted, isFalse);
      },
    );

    test(
      'GivenAnAnswerWithNoFields_WhenGoogleSignInSet_ThenWhatWasSentFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(emptyData);

        // When
        final result = await repository.setGoogleSignIn(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        final scope = result.valueOrNull!;
        expect(scope.id, 'scope-1');
        expect(scope.name, '');
        expect(scope.description, '');
        expect(scope.googleSignInEnabled, isTrue);
        expect(scope.emailVerificationUrl, isNull);
        expect(scope.passwordResetUrl, isNull);
        expect(scope.ownerIds, isEmpty);
        expect(scope.createdAt, isNull);
        expect(scope.updatedAt, isNull);
      },
    );

    test(
      'GivenNoData_WhenGoogleSignInSet_ThenAnIncompleteAnswerIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.setGoogleSignIn(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incomplete);
      },
    );

    // AF-15a — the API refused, and its own strings say why.
    test(
      'GivenARefusal_WhenGoogleSignInSet_ThenApiErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await repository.setGoogleSignIn(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>[
          'A scope with this name already exists.',
        ]);
      },
    );

    test(
      'GivenARefusalWithoutErrors_WhenGoogleSignInSet_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.setGoogleSignIn(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenNoConnection_WhenGoogleSignInSet_ThenNetworkIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.setGoogleSignIn(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('setSelfRegistration', () {
    test('GivenSelfRegistration_WhenClosed_ThenItIsPutToTheScope', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await repository.setSelfRegistration(id: 'scope-1', enabled: false);

      // Then
      expect(adapter.methods.single, 'PUT');
      expect(adapter.paths.single, '/api/scopes/scope-1/self-registration');
      expect(adapter.requests.single, <String, dynamic>{'enabled': false});
    });

    test('GivenAnAnswer_WhenSelfRegistrationSet_ThenItIsMapped', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await repository.setSelfRegistration(
        id: 'scope-1',
        enabled: true,
      );

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, 'scope-9');
      expect(scope.name, 'Globex');
      expect(scope.description, 'The second tenant');
      expect(scope.googleSignInEnabled, isTrue);
      expect(scope.selfRegistrationEnabled, isTrue);
      expect(scope.passwordResetUrl, 'https://globex.example/password-reset');
      expect(scope.ownerIds, <String>['person-7', 'person-8']);
      expect(scope.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(scope.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(scope.isDeleted, isFalse);
      expect(scope.defaultLegalBasis, isNull);
      expect(scope.privacyNoticeUri, isNull);
    });

    test('GivenAnAnswerWithNoFields_WhenSelfRegistrationSet_ThenWhatWasSentFillsIt', () async {
      // Given
      final repository = repositoryAnswering(emptyData);

      // When
      final result = await repository.setSelfRegistration(
        id: 'scope-1',
        enabled: true,
      );

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, 'scope-1');
      expect(scope.name, '');
      expect(scope.description, '');
      expect(scope.googleSignInEnabled, isFalse);
      expect(scope.selfRegistrationEnabled, isTrue);
      expect(scope.emailVerificationUrl, isNull);
      expect(scope.passwordResetUrl, isNull);
      expect(scope.ownerIds, isEmpty);
      expect(scope.createdAt, isNull);
      expect(scope.updatedAt, isNull);
    });

    test(
      'GivenNoData_WhenSelfRegistrationSet_ThenAnIncompleteAnswerIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.setSelfRegistration(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incomplete);
      },
    );

    test(
      'GivenARefusal_WhenSelfRegistrationSet_ThenApiErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await repository.setSelfRegistration(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>[
          'A scope with this name already exists.',
        ]);
      },
    );

    test('GivenARefusalWithoutErrors_WhenSelfRegistrationSet_ThenNoErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refusedWithoutReason);

      // When
      final result = await repository.setSelfRegistration(
        id: 'scope-1',
        enabled: true,
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, isEmpty);
    });

    test(
      'GivenNoConnection_WhenSelfRegistrationSet_ThenNetworkIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.setSelfRegistration(
          id: 'scope-1',
          enabled: true,
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('setEmailLinks', () {
    Future<Result<Scope>> setLinksIn(ApiScopeRepository repository) =>
        repository.setEmailLinks(
          id: 'scope-1',
          emailVerificationUrl: 'https://acme.example/verify-email',
          passwordResetUrl: 'https://acme.example/password-reset',
        );

    test('GivenEmailLinks_WhenSet_ThenTheyArePutToTheScope', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      await setLinksIn(repository);

      // Then
      expect(adapter.methods.single, 'PUT');
      expect(adapter.paths.single, '/api/scopes/scope-1/email-links');
      expect(adapter.requests.single, <String, dynamic>{
        'emailVerificationUrl': 'https://acme.example/verify-email',
        'passwordResetUrl': 'https://acme.example/password-reset',
      });
    });

    test('GivenAnAnswer_WhenEmailLinksSet_ThenItIsMapped', () async {
      // Given
      final repository = repositoryAnswering(fullData);

      // When
      final result = await setLinksIn(repository);

      // Then
      final scope = result.valueOrNull!;
      expect(scope.id, 'scope-9');
      expect(scope.name, 'Globex');
      expect(scope.description, 'The second tenant');
      expect(scope.googleSignInEnabled, isTrue);
      expect(scope.selfRegistrationEnabled, isTrue);
      expect(scope.emailVerificationUrl, 'https://globex.example/verify-email');
      expect(scope.passwordResetUrl, 'https://globex.example/password-reset');
      expect(scope.ownerIds, <String>['person-7', 'person-8']);
      expect(scope.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(scope.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(scope.isDeleted, isFalse);
      expect(scope.defaultLegalBasis, isNull);
      expect(scope.privacyNoticeUri, isNull);
    });

    test(
      'GivenAnAnswerWithNoFields_WhenEmailLinksSet_ThenTheDefaultsAreUsed',
      () async {
        // Given
        final repository = repositoryAnswering(emptyData);

        // When
        final result = await setLinksIn(repository);

        // Then
        final scope = result.valueOrNull!;
        expect(scope.id, 'scope-1');
        expect(scope.name, '');
        expect(scope.description, '');
        expect(scope.googleSignInEnabled, isFalse);
        expect(scope.selfRegistrationEnabled, isFalse);
        expect(scope.emailVerificationUrl, isNull);
        expect(scope.passwordResetUrl, isNull);
        expect(scope.ownerIds, isEmpty);
        expect(scope.createdAt, isNull);
        expect(scope.updatedAt, isNull);
      },
    );

    // The API clears a link sent empty, so a blank one is no override.
    test('GivenClearedLinks_WhenEmailLinksSet_ThenThereAreNoLinks', () async {
      // Given
      final repository = repositoryAnswering(blankLinks);

      // When
      final result = await setLinksIn(repository);

      // Then
      expect(result.valueOrNull!.emailVerificationUrl, isNull);
      expect(result.valueOrNull!.passwordResetUrl, isNull);
      expect(result.valueOrNull!.hasCustomEmailLinks, isFalse);
    });

    test(
      'GivenNoData_WhenEmailLinksSet_ThenAnIncompleteAnswerIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await setLinksIn(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incomplete);
      },
    );

    test(
      'GivenARefusalWithoutErrors_WhenEmailLinksSet_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await setLinksIn(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );
  });

  group('delete', () {
    const deleted = StubAnswer(
      status: 200,
      body: <String, dynamic>{
        'success': true,
        'errors': <String>[],
        'data': <String, dynamic>{'id': 'scope-1'},
      },
    );

    const stillHoldsUsers = StubAnswer(
      status: 200,
      body: <String, dynamic>{
        'success': false,
        'errors': <String>['The scope still has users.'],
      },
    );

    test('GivenAScope_WhenDeleted_ThenItIsAddressed', () async {
      // Given
      final repository = repositoryAnswering(deleted);

      // When
      final result = await repository.delete('scope-1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/api/scopes/scope-1');
    });

    // Nothing in the answer is read: the envelope's success is the outcome.
    test(
      'GivenAnAcknowledgementWithoutData_WhenDeleted_ThenItIsASuccess',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.delete('scope-1');

        // Then
        expect(result.isSuccess, isTrue);
      },
    );

    // AF-13b — the API will not delete a scope that still holds users.
    test('GivenARefusal_WhenDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(stillHoldsUsers);

      // When
      final result = await repository.delete('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'The scope still has users.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenDeleted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.delete('scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    // AF-13d — somebody already deleted it.
    test('GivenAGoneScope_WhenDeleted_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(notFound);

      // When
      final result = await repository.delete('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
      expect(result.failureOrNull?.errors, <String>['Scope not found.']);
    });

    test('GivenNoConnection_WhenDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.delete('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('hardDelete', () {
    const hardDeleted = StubAnswer(
      status: 200,
      body: <String, dynamic>{
        'success': true,
        'errors': <String>[],
        'data': <String, dynamic>{'id': 'scope-1'},
      },
    );

    test('GivenAScope_WhenHardDeleted_ThenItsHardPathIsAddressed', () async {
      // Given
      final repository = repositoryAnswering(hardDeleted);

      // When
      final result = await repository.hardDelete('scope-1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/api/scopes/scope-1/hard');
    });

    test('GivenARefusal_WhenHardDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.hardDelete('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'A scope with this name already exists.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenHardDeleted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.hardDelete('scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenAGoneScope_WhenHardDeleted_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(notFound);

      // When
      final result = await repository.hardDelete('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    test('GivenNoConnection_WhenHardDeleted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.hardDelete('scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });
}
