import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/data/person_repository_impl.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiPersonRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiPersonRepository(PersonClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test(
    'GivenAScopeAdminsAdd_WhenTheApiInvites_ThenTheOutcomeIsInvited',
    () async {
      // Given - FR-SC-14: 202 and invited
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 202,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'messages': <String>['The invitation was sent.'],
            'data': <String, dynamic>{
              'scopeId': 's1',
              'personId': 'p7',
              'alreadyOwner': false,
              'invited': true,
              'invitationId': 'i1',
              'invitationExpiresAt': '2026-10-23T09:00:00Z',
            },
          },
        ),
      );

      // When
      final result = await repository.addScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.valueOrNull, AddOwnerOutcome.invited);
    },
  );

  test('GivenASystemAdminsAdd_WhenTheApiAdds_ThenTheOutcomeIsAdded', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 201,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'scopeId': 's1',
            'personId': 'p7',
            'alreadyOwner': false,
            'invited': false,
          },
        },
      ),
    );

    // When
    final result = await repository.addScopeOwner(
      scopeId: 's1',
      personId: 'p7',
    );

    // Then
    expect(result.valueOrNull, AddOwnerOutcome.added);
  });

  test(
    'GivenAnOlderApisCreated_WhenTheBodyHasNoInvited_ThenTheOutcomeIsAdded',
    () async {
      // Given - an API from before FR-SC-14, whose answer has no `invited`
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 201,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{
              'scopeId': 's1',
              'personId': 'p7',
              'alreadyOwner': false,
            },
          },
        ),
      );

      // When
      final result = await repository.addScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.valueOrNull, AddOwnerOutcome.added);
    },
  );

  test(
    'GivenAnAcceptedStatus_WhenTheBodySaysNotInvited_ThenTheOutcomeIsAdded',
    () async {
      // Given - the outcome is read from the body, never the status code
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 202,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{
              'scopeId': 's1',
              'personId': 'p7',
              'alreadyOwner': false,
              'invited': false,
            },
          },
        ),
      );

      // When
      final result = await repository.addScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.valueOrNull, AddOwnerOutcome.added);
    },
  );

  test('GivenAnExistingOwner_WhenAdded_ThenTheOutcomeIsAlreadyOwner', () async {
    // Given - AF-21d
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'scopeId': 's1',
            'personId': 'p7',
            'alreadyOwner': true,
            'invited': false,
          },
        },
      ),
    );

    // When
    final result = await repository.addScopeOwner(
      scopeId: 's1',
      personId: 'p7',
    );

    // Then
    expect(result.valueOrNull, AddOwnerOutcome.alreadyOwner);
  });

  test('GivenAPersonResponse_WhenReadById_ThenThePersonIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
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
        const StubAnswer(
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
      const StubAnswer(
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
        const StubAnswer(
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
      const StubAnswer(
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

  // FR-AU-16 — changing your own address re-authenticates in the request.
  test(
    'GivenAReauthentication_WhenUpdated_ThenThePasswordAndCodeAreSent',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{'id': 'person-1'},
          },
        ),
      );

      // When
      await repository.update(
        id: 'person-1',
        name: 'Ada',
        email: 'new@example.com',
        currentPassword: 'secret',
        twoFactorCode: '123456',
      );

      // Then
      expect(adapter.requests.single['currentPassword'], 'secret');
      expect(adapter.requests.single['twoFactorCode'], '123456');
    },
  );

  test('GivenAnOrdinaryEdit_WhenUpdated_ThenNoPasswordIsSent', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
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
    expect(adapter.requests.single['currentPassword'], isNull);
    expect(adapter.requests.single['twoFactorCode'], isNull);
  });

  // AF-08b — the API's own strings are what the screen shows.
  test('GivenARejectedUpdate_WhenUpdated_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
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
    final repository = repositoryAnswering(const StubAnswer(status: 0));

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
        const StubAnswer(
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
      const StubAnswer(
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
    expect(
      adapter.uris.single.queryParameters['ExcludeOwnersOfScopeId'],
      'scope-1',
    );
  });

  // An empty filter is no filter: sent, it would ask the API to match the
  // empty string rather than to stop narrowing.
  test('GivenABlankQuery_WhenListed_ThenNoFilterIsSent', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
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
    expect(adapter.uris.single.queryParameters.containsKey('Name'), isFalse);
    expect(
      adapter.uris.single.queryParameters.containsKey('ExcludeOwnersOfScopeId'),
      isFalse,
    );
  });

  test('GivenNoConnection_WhenListed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.listScopeAdmins();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });

  test('GivenASecondFactor_WhenReadById_ThenItIsCarried', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
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

  test(
    'GivenAPerson_WhenAVerificationEmailIsSent_ThenTheirIdIsAddressed',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{'id': 'p1'},
          },
        ),
      );

      // When
      final result = await repository.sendVerificationEmail('p1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.paths.single, '/api/persons/p1/verification-email');
    },
  );

  test('GivenAPerson_WhenAResetIsSent_ThenTheirIdIsAddressed', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'id': 'p1'},
        },
      ),
    );

    // When
    final result = await repository.sendPasswordReset('p1');

    // Then
    expect(result.isSuccess, isTrue);
    expect(adapter.paths.single, '/api/persons/p1/password-reset');
  });

  test('GivenACooldown_WhenAResetIsSent_ThenTheFailureIsRateLimitedWithTheApiMessage', () async {
    // Given — AF-36a
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 429,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>[
            'An email of this kind was sent to this person recently. Try again in a few minutes.',
          ],
        },
      ),
    );

    // When
    final result = await repository.sendPasswordReset('p1');

    // Then
    expect(result.failureOrNull!.kind, FailureKind.rateLimited);
    expect(
      result.failureOrNull!.errors.single,
      startsWith('An email of this kind'),
    );
  });

  test('GivenSystemAdmins_WhenListed_ThenTheyAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'admin-1',
              'name': 'Ada',
              'email': 'ada@example.com',
            },
          ],
          'pageNumber': 2,
          'pageSize': 20,
          'totalItems': 21,
          'totalPages': 2,
        },
      ),
    );

    // When
    final result = await repository.listSystemAdmins(pageNumber: 2);

    // Then
    final page = result.valueOrNull!;
    expect(page.items.single.id, 'admin-1');
    expect(page.items.single.name, 'Ada');
    expect(page.totalItems, 21);
    expect(adapter.paths.single, '/api/persons/system-admins');
    expect(adapter.uris.single.queryParameters['PageNumber'], '2');
    expect(adapter.uris.single.queryParameters['PageSize'], '20');
  });

  test('GivenFilters_WhenSystemAdminsListed_ThenTheyAreSent', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
        },
      ),
    );

    // When
    await repository.listSystemAdmins(name: 'Ada', email: '  ');

    // Then
    expect(adapter.uris.single.queryParameters['Name'], 'Ada');
    expect(adapter.uris.single.queryParameters.containsKey('Email'), isFalse);
    expect(adapter.uris.single.queryParameters['PageNumber'], '1');
    expect(adapter.uris.single.queryParameters['PageSize'], '20');
  });

  test('GivenA403_WhenSystemAdminsListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 403,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Only a System Admin may list System Admins.'],
        },
      ),
    );

    // When
    final result = await repository.listSystemAdmins();

    // Then
    expect(result.failureOrNull?.kind, FailureKind.forbidden);
  });

  test(
    'GivenSuccessFalse_WhenSystemAdminsListed_ThenValidationErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['The page size is too large.'],
          },
        ),
      );

      // When
      final result = await repository.listSystemAdmins();

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'The page size is too large.',
      ]);
    },
  );
}
