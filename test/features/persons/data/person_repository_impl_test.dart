import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/data/person_repository_impl.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
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

  const person = <String, dynamic>{
    'id': 'person-1',
    'name': 'Ada',
    'email': 'ada@example.com',
    'role': 2,
    'emailVerified': false,
    'twoFactorEnabled': true,
    'isDeleted': true,
    'scopeId': 'scope-1',
    'ownedScopeIds': <String>['scope-1', 'scope-2'],
    'createdAt': '2026-01-02T03:04:05.000Z',
    'updatedAt': '2026-02-03T04:05:06.000Z',
  };

  const created = <String, dynamic>{
    'id': 'person-9',
    'name': 'Grace',
    'email': 'grace@example.com',
    'role': 1,
    'emailVerified': true,
    'scopeId': 'scope-1',
    'createdAt': '2026-01-02T03:04:05.000Z',
  };

  const onePersonPage = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[person],
      'pageNumber': 2,
      'pageSize': 10,
      'totalItems': 11,
      'totalPages': 2,
    },
  );

  const emptyPage = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[],
    },
  );

  const refused = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['The API refused this.'],
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

  const noConnection = StubAnswer(status: 0);

  StubAnswer answeringStatus(int status) => StubAnswer(
    status: status,
    body: const <String, dynamic>{
      'success': false,
      'errors': <String>['Refused by status.'],
    },
  );

  StubAnswer answeringData(Map<String, dynamic> data) => StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': const <String>[],
      'data': data,
    },
  );

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  group('getById', () {
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
      'GivenNoConnection_WhenReadById_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(const StubAnswer(status: 0));

        // When
        final result = await repository.getById('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );

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

    test('GivenAFullPerson_WhenReadById_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(answeringData(person));

      // When
      final result = await repository.getById('person-1');

      // Then
      final value = result.valueOrNull!;
      expect(value.id, 'person-1');
      expect(value.name, 'Ada');
      expect(value.email, 'ada@example.com');
      expect(value.role, Role.scopeAdmin);
      expect(value.emailVerified, isFalse);
      expect(value.twoFactorEnabled, isTrue);
      expect(value.isDeleted, isTrue);
      expect(value.scopeId, 'scope-1');
      expect(value.ownedScopeIds, <String>['scope-1', 'scope-2']);
      expect(value.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(value.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
    });

    test(
      'GivenAPersonWithNoFields_WhenReadById_ThenTheDefaultsAreUsed',
      () async {
        // Given
        final repository = repositoryAnswering(
          answeringData(const <String, dynamic>{}),
        );

        // When
        final result = await repository.getById('person-1');

        // Then
        final value = result.valueOrNull!;
        expect(value.id, '');
        expect(value.name, '');
        expect(value.email, '');
        expect(value.role, Role.user);
        expect(value.emailVerified, isTrue);
        expect(value.twoFactorEnabled, isFalse);
        expect(value.isDeleted, isFalse);
        expect(value.scopeId, isNull);
        expect(value.ownedScopeIds, isEmpty);
        expect(value.createdAt, isNull);
        expect(value.updatedAt, isNull);
      },
    );

    test(
      'GivenNoFlag_WhenReadById_ThenAGetAsksWithoutDeletedPersons',
      () async {
        // Given
        final repository = repositoryAnswering(answeringData(person));

        // When
        await repository.getById('person-1');

        // Then
        expect(adapter.methods.single, 'GET');
        expect(adapter.paths.single, '/api/persons/person-1');
        expect(adapter.queries.single, containsPair('includeDeleted', false));
      },
    );

    test('GivenIncludeDeleted_WhenReadById_ThenTheFlagIsSent', () async {
      // Given
      final repository = repositoryAnswering(answeringData(person));

      // When
      await repository.getById('person-1', includeDeleted: true);

      // Then
      expect(adapter.queries.single, containsPair('includeDeleted', true));
    });

    test(
      'GivenSuccessFalse_WhenReadById_ThenValidationErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await repository.getById('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test(
      'GivenSuccessFalseWithoutErrors_WhenReadById_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.getById('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenNoData_WhenReadById_ThenAnIncompleteResponseIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.getById('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incompleteResponse.errors);
      },
    );

    test('GivenA403_WhenReadById_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await repository.getById('person-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
      expect(result.failureOrNull?.errors, <String>['Refused by status.']);
    });
  });

  group('update', () {
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

    test(
      'GivenARoleChange_WhenUpdated_ThenAPutToThePersonCarriesTheCommand',
      () async {
        // Given
        final repository = repositoryAnswering(
          answeringData(const <String, dynamic>{'id': 'person-1'}),
        );

        // When
        await repository.update(
          id: 'person-1',
          name: 'Ada',
          email: 'ada@example.com',
          roleId: 1,
        );

        // Then
        expect(adapter.methods.single, 'PUT');
        expect(adapter.paths.single, '/api/persons/person-1');
        expect(adapter.requests.single, containsPair('name', 'Ada'));
        expect(
          adapter.requests.single,
          containsPair('email', 'ada@example.com'),
        );
        expect(adapter.requests.single, containsPair('roleId', 1));
      },
    );

    test('GivenAFullAnswer_WhenUpdated_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(
        answeringData(const <String, dynamic>{
          'id': 'person-1',
          'name': 'Ada L',
          'email': 'ada.l@example.com',
          'role': 1,
          'emailVerified': false,
          'scopeId': 'scope-1',
          'ownedScopeIds': <String>['scope-2'],
          'createdAt': '2026-01-02T03:04:05.000Z',
          'updatedAt': '2026-02-03T04:05:06.000Z',
        }),
      );

      // When
      final result = await repository.update(
        id: 'person-1',
        name: 'Ada',
        email: 'ada@example.com',
      );

      // Then
      final value = result.valueOrNull!;
      expect(value.id, 'person-1');
      expect(value.name, 'Ada L');
      expect(value.email, 'ada.l@example.com');
      expect(value.role, Role.systemAdmin);
      expect(value.emailVerified, isFalse);
      expect(value.scopeId, 'scope-1');
      expect(value.ownedScopeIds, <String>['scope-2']);
      expect(value.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(value.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(value.isDeleted, isFalse);
      expect(value.twoFactorEnabled, isFalse);
    });

    test(
      'GivenAnAnswerWithNoFields_WhenUpdated_ThenTheSentValuesFillIt',
      () async {
        // Given
        final repository = repositoryAnswering(
          answeringData(const <String, dynamic>{}),
        );

        // When
        final result = await repository.update(
          id: 'person-1',
          name: 'Ada',
          email: 'ada@example.com',
        );

        // Then
        final value = result.valueOrNull!;
        expect(value.id, 'person-1');
        expect(value.name, 'Ada');
        expect(value.email, 'ada@example.com');
        expect(value.role, Role.user);
        expect(value.emailVerified, isTrue);
        expect(value.scopeId, isNull);
        expect(value.ownedScopeIds, isEmpty);
        expect(value.createdAt, isNull);
        expect(value.updatedAt, isNull);
        expect(value.isDeleted, isFalse);
      },
    );

    test(
      'GivenSuccessFalseWithoutErrors_WhenUpdated_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.update(
          id: 'person-1',
          name: 'Ada',
          email: 'ada@example.com',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenNoData_WhenUpdated_ThenAnIncompleteResponseIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.update(
          id: 'person-1',
          name: 'Ada',
          email: 'ada@example.com',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incompleteResponse.errors);
      },
    );

    test('GivenA409_WhenUpdated_ThenConflictIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(409));

      // When
      final result = await repository.update(
        id: 'person-1',
        name: 'Ada',
        email: 'taken@example.com',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.conflict);
      expect(result.failureOrNull?.errors, <String>['Refused by status.']);
    });

    test(
      'GivenAWrongPassword_WhenUpdated_ThenTheFailureIsAValidationOne',
      () async {
        // Given - FR-AU-16: a mistyped password is not the session ending
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 401,
            body: <String, dynamic>{
              'success': false,
              'errors': <String>['The password or code is incorrect.'],
            },
          ),
        );

        // When
        final result = await repository.update(
          id: 'person-1',
          name: 'Ada',
          email: 'new@example.com',
          currentPassword: 'wrong',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>[
          'The password or code is incorrect.',
        ]);
      },
    );

    test(
      'GivenNoConnection_WhenUpdated_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.update(
          id: 'person-1',
          name: 'Ada',
          email: 'ada@example.com',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('createUser', () {
    Future<Result<Person>> createUser(ApiPersonRepository repository) =>
        repository.createUser(
          scopeId: 'scope-1',
          name: 'Grace',
          email: 'grace@example.com',
          password: 'Secret#123',
        );

    test(
      'GivenAUser_WhenCreated_ThenAPostToTheScopeCarriesTheCommand',
      () async {
        // Given
        final repository = repositoryAnswering(answeringData(created));

        // When
        await createUser(repository);

        // Then
        expect(adapter.methods.single, 'POST');
        expect(adapter.paths.single, '/api/scopes/scope-1/persons');
        expect(adapter.requests.single, <String, dynamic>{
          'name': 'Grace',
          'email': 'grace@example.com',
          'password': 'Secret#123',
        });
      },
    );

    test('GivenAFullAnswer_WhenUserCreated_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(answeringData(created));

      // When
      final result = await createUser(repository);

      // Then
      final value = result.valueOrNull!;
      expect(value.id, 'person-9');
      expect(value.name, 'Grace');
      expect(value.email, 'grace@example.com');
      expect(value.role, Role.systemAdmin);
      expect(value.emailVerified, isTrue);
      expect(value.scopeId, 'scope-1');
      expect(value.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(value.updatedAt, isNull);
      expect(value.ownedScopeIds, isEmpty);
    });

    test('GivenAnAnswerWithNoFields_WhenUserCreated_ThenTheSentValuesAndUserRoleFillIt', () async {
      // Given
      final repository = repositoryAnswering(
        answeringData(const <String, dynamic>{}),
      );

      // When
      final result = await createUser(repository);

      // Then
      final value = result.valueOrNull!;
      expect(value.id, '');
      expect(value.name, 'Grace');
      expect(value.email, 'grace@example.com');
      expect(value.role, Role.user);
      expect(value.emailVerified, isFalse);
      expect(value.scopeId, isNull);
      expect(value.createdAt, isNull);
    });

    // AF-17b — a registered address is told in the API's own words.
    test(
      'GivenARegisteredAddress_WhenUserCreated_ThenApiErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await createUser(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test(
      'GivenSuccessFalseWithoutErrors_WhenUserCreated_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await createUser(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenNoData_WhenUserCreated_ThenAnIncompleteResponseIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await createUser(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incompleteResponse.errors);
      },
    );

    test('GivenA403_WhenUserCreated_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await createUser(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test(
      'GivenNoConnection_WhenUserCreated_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await createUser(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('createAdmin', () {
    Future<Result<Person>> createAdmin(
      ApiPersonRepository repository, {
      Role role = Role.scopeAdmin,
    }) => repository.createAdmin(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'Secret#123',
      role: role,
    );

    test(
      'GivenAnAdmin_WhenCreated_ThenAPostCarriesTheCommandAndRoleValue',
      () async {
        // Given
        final repository = repositoryAnswering(answeringData(created));

        // When
        await createAdmin(repository);

        // Then
        expect(adapter.methods.single, 'POST');
        expect(adapter.paths.single, '/api/persons');
        expect(adapter.requests.single, <String, dynamic>{
          'name': 'Grace',
          'email': 'grace@example.com',
          'password': 'Secret#123',
          'role': 2,
        });
      },
    );

    test('GivenAFullAnswer_WhenAdminCreated_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(answeringData(created));

      // When
      final result = await createAdmin(repository);

      // Then
      final value = result.valueOrNull!;
      expect(value.id, 'person-9');
      expect(value.name, 'Grace');
      expect(value.email, 'grace@example.com');
      expect(value.role, Role.systemAdmin);
      expect(value.emailVerified, isTrue);
      expect(value.scopeId, 'scope-1');
      expect(value.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    test(
      'GivenAnAnswerWithNoFields_WhenAdminCreated_ThenTheRequestedRoleFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(
          answeringData(const <String, dynamic>{}),
        );

        // When
        final result = await createAdmin(repository, role: Role.systemAdmin);

        // Then
        final value = result.valueOrNull!;
        expect(value.id, '');
        expect(value.name, 'Grace');
        expect(value.email, 'grace@example.com');
        expect(value.role, Role.systemAdmin);
        expect(value.emailVerified, isFalse);
        expect(value.scopeId, isNull);
        expect(value.createdAt, isNull);
      },
    );

    // AF-17c — a password the policy refuses is told in the API's own words.
    test(
      'GivenARefusedPassword_WhenAdminCreated_ThenApiErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await createAdmin(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test(
      'GivenSuccessFalseWithoutErrors_WhenAdminCreated_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await createAdmin(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenNoData_WhenAdminCreated_ThenAnIncompleteResponseIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await createAdmin(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incompleteResponse.errors);
      },
    );

    test('GivenA409_WhenAdminCreated_ThenConflictIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(409));

      // When
      final result = await createAdmin(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.conflict);
      expect(result.failureOrNull?.errors, <String>['Refused by status.']);
    });

    test(
      'GivenNoConnection_WhenAdminCreated_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await createAdmin(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('createScopeOwner', () {
    Future<Result<Person>> createScopeOwner(ApiPersonRepository repository) =>
        repository.createScopeOwner(
          scopeId: 'scope-1',
          name: 'Grace',
          email: 'grace@example.com',
          password: 'Secret#123',
        );

    test(
      'GivenAnOwner_WhenCreated_ThenAPostToTheScopeOwnersCarriesTheCommand',
      () async {
        // Given
        final repository = repositoryAnswering(answeringData(created));

        // When
        await createScopeOwner(repository);

        // Then
        expect(adapter.methods.single, 'POST');
        expect(adapter.paths.single, '/api/scopes/scope-1/owners');
        expect(adapter.requests.single, <String, dynamic>{
          'name': 'Grace',
          'email': 'grace@example.com',
          'password': 'Secret#123',
        });
      },
    );

    test('GivenAFullAnswer_WhenOwnerCreated_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(answeringData(created));

      // When
      final result = await createScopeOwner(repository);

      // Then
      final value = result.valueOrNull!;
      expect(value.id, 'person-9');
      expect(value.name, 'Grace');
      expect(value.email, 'grace@example.com');
      expect(value.role, Role.systemAdmin);
      expect(value.emailVerified, isTrue);
      expect(value.scopeId, 'scope-1');
      expect(value.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    test('GivenAnAnswerWithNoFields_WhenOwnerCreated_ThenTheSentValuesAndScopeAdminRoleFillIt', () async {
      // Given
      final repository = repositoryAnswering(
        answeringData(const <String, dynamic>{}),
      );

      // When
      final result = await createScopeOwner(repository);

      // Then
      final value = result.valueOrNull!;
      expect(value.id, '');
      expect(value.name, 'Grace');
      expect(value.email, 'grace@example.com');
      expect(value.role, Role.scopeAdmin);
      expect(value.emailVerified, isFalse);
      expect(value.scopeId, isNull);
      expect(value.createdAt, isNull);
    });

    // AF-14d — a rejected name, address, or password.
    test(
      'GivenARejectedField_WhenOwnerCreated_ThenApiErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await createScopeOwner(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test(
      'GivenSuccessFalseWithoutErrors_WhenOwnerCreated_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await createScopeOwner(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenNoData_WhenOwnerCreated_ThenAnIncompleteResponseIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await createScopeOwner(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.unknown);
        expect(result.failureOrNull?.errors, incompleteResponse.errors);
      },
    );

    test('GivenA403_WhenOwnerCreated_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await createScopeOwner(repository);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test(
      'GivenNoConnection_WhenOwnerCreated_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await createScopeOwner(repository);

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('delete', () {
    test('GivenAPerson_WhenDeleted_ThenADeleteAddressesThem', () async {
      // Given
      final repository = repositoryAnswering(acknowledged);

      // When
      final result = await repository.delete('person-1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/api/persons/person-1');
    });

    // AF-19b — the last owner of a scope, for instance, is refused.
    test('GivenARefusal_WhenDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.delete('person-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['The API refused this.']);
    });

    test(
      'GivenSuccessFalseWithoutErrors_WhenDeleted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.delete('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenAnEnvelopeWithoutSuccess_WhenDeleted_ThenItIsAFailure',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(status: 200, body: <String, dynamic>{}),
        );

        // When
        final result = await repository.delete('person-1');

        // Then
        expect(result.isSuccess, isFalse);
        expect(result.failureOrNull?.kind, FailureKind.validation);
      },
    );

    test('GivenA404_WhenDeleted_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(404));

      // When
      final result = await repository.delete('gone');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    test(
      'GivenNoConnection_WhenDeleted_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.delete('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('hardDelete', () {
    test(
      'GivenAPerson_WhenHardDeleted_ThenADeleteAddressesTheHardPath',
      () async {
        // Given
        final repository = repositoryAnswering(acknowledged);

        // When
        final result = await repository.hardDelete('person-1');

        // Then
        expect(result.isSuccess, isTrue);
        expect(adapter.methods.single, 'DELETE');
        expect(adapter.paths.single, '/api/persons/person-1/hard');
      },
    );

    test('GivenARefusal_WhenHardDeleted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.hardDelete('person-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['The API refused this.']);
    });

    test(
      'GivenSuccessFalseWithoutErrors_WhenHardDeleted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.hardDelete('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenA403_WhenHardDeleted_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await repository.hardDelete('person-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test(
      'GivenNoConnection_WhenHardDeleted_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.hardDelete('person-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('listScopeOwners', () {
    test('GivenAPage_WhenOwnersListed_ThenEveryFieldIsMapped', () async {
      // Given
      final repository = repositoryAnswering(onePersonPage);

      // When
      final result = await repository.listScopeOwners(scopeId: 'scope-1');

      // Then
      final page = result.valueOrNull!;
      final item = page.items.single;
      expect(item.id, 'person-1');
      expect(item.name, 'Ada');
      expect(item.email, 'ada@example.com');
      expect(item.role, Role.scopeAdmin);
      expect(item.emailVerified, isFalse);
      expect(item.twoFactorEnabled, isTrue);
      expect(item.isDeleted, isTrue);
      expect(item.scopeId, 'scope-1');
      expect(item.ownedScopeIds, <String>['scope-1', 'scope-2']);
      expect(item.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(item.updatedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(page.pageNumber, 2);
      expect(page.pageSize, 10);
      expect(page.totalItems, 11);
      expect(page.totalPages, 2);
    });

    test(
      'GivenFiltersAndPaging_WhenOwnersListed_ThenTheyTravelTrimmed',
      () async {
        // Given
        final repository = repositoryAnswering(onePersonPage);

        // When
        await repository.listScopeOwners(
          scopeId: 'scope-1',
          name: '  Ada  ',
          email: ' ada@example.com ',
          includeDeleted: true,
          pageNumber: 3,
          pageSize: 50,
        );

        // Then
        expect(adapter.methods.single, 'GET');
        expect(adapter.paths.single, '/api/scopes/scope-1/owners');
        expect(adapter.queries.single, <String, dynamic>{
          'Name': 'Ada',
          'Email': 'ada@example.com',
          'IncludeDeleted': true,
          'PageNumber': 3,
          'PageSize': 50,
        });
      },
    );

    test('GivenNoArguments_WhenOwnersListed_ThenTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(onePersonPage);

      // When
      await repository.listScopeOwners(scopeId: 'scope-1');

      // Then
      expect(adapter.queries.single, <String, dynamic>{
        'IncludeDeleted': false,
        'PageNumber': 1,
        'PageSize': 20,
      });
    });

    test('GivenBlankFilters_WhenOwnersListed_ThenNoFilterIsSent', () async {
      // Given
      final repository = repositoryAnswering(onePersonPage);

      // When
      await repository.listScopeOwners(
        scopeId: 'scope-1',
        name: '   ',
        email: '',
      );

      // Then
      expect(adapter.queries.single.containsKey('Name'), isFalse);
      expect(adapter.queries.single.containsKey('Email'), isFalse);
    });

    test('GivenAnEnvelopeWithoutPaging_WhenOwnersListed_ThenTheRequestAndItemsFillIt', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[person, person],
          },
        ),
      );

      // When
      final result = await repository.listScopeOwners(
        scopeId: 'scope-1',
        pageNumber: 4,
        pageSize: 5,
      );

      // Then
      final page = result.valueOrNull!;
      expect(page.items, hasLength(2));
      expect(page.pageNumber, 4);
      expect(page.pageSize, 5);
      expect(page.totalItems, 2);
      expect(page.totalPages, 1);
    });

    test('GivenNoData_WhenOwnersListed_ThenThePageIsEmpty', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.listScopeOwners(scopeId: 'scope-1');

      // Then
      final page = result.valueOrNull!;
      expect(page.items, isEmpty);
      expect(page.totalItems, 0);
      expect(page.totalPages, 1);
    });

    test(
      'GivenSuccessFalse_WhenOwnersListed_ThenValidationErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await repository.listScopeOwners(scopeId: 'scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test(
      'GivenSuccessFalseWithoutErrors_WhenOwnersListed_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.listScopeOwners(scopeId: 'scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenA403_WhenOwnersListed_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await repository.listScopeOwners(scopeId: 'scope-1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test(
      'GivenNoConnection_WhenOwnersListed_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.listScopeOwners(scopeId: 'scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('listScopePersons', () {
    test('GivenAPage_WhenPersonsListed_ThenItIsMapped', () async {
      // Given
      final repository = repositoryAnswering(onePersonPage);

      // When
      final result = await repository.listScopePersons(scopeId: 'scope-1');

      // Then
      final page = result.valueOrNull!;
      expect(page.items.single.id, 'person-1');
      expect(page.items.single.role, Role.scopeAdmin);
      expect(page.pageNumber, 2);
      expect(page.pageSize, 10);
      expect(page.totalItems, 11);
      expect(page.totalPages, 2);
    });

    test(
      'GivenFiltersAndPaging_WhenPersonsListed_ThenTheyTravelTrimmed',
      () async {
        // Given
        final repository = repositoryAnswering(emptyPage);

        // When
        await repository.listScopePersons(
          scopeId: 'scope-1',
          name: '  Ada  ',
          email: ' ada@example.com ',
          includeDeleted: true,
          pageNumber: 3,
          pageSize: 50,
        );

        // Then
        expect(adapter.methods.single, 'GET');
        expect(adapter.paths.single, '/api/scopes/scope-1/persons');
        expect(adapter.queries.single, <String, dynamic>{
          'Name': 'Ada',
          'Email': 'ada@example.com',
          'IncludeDeleted': true,
          'PageNumber': 3,
          'PageSize': 50,
        });
      },
    );

    test('GivenNoArguments_WhenPersonsListed_ThenTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(emptyPage);

      // When
      await repository.listScopePersons(scopeId: 'scope-1');

      // Then
      expect(adapter.queries.single, <String, dynamic>{
        'IncludeDeleted': false,
        'PageNumber': 1,
        'PageSize': 20,
      });
    });

    test('GivenBlankFilters_WhenPersonsListed_ThenNoFilterIsSent', () async {
      // Given
      final repository = repositoryAnswering(emptyPage);

      // When
      await repository.listScopePersons(
        scopeId: 'scope-1',
        name: '',
        email: '   ',
      );

      // Then
      expect(adapter.queries.single.containsKey('Name'), isFalse);
      expect(adapter.queries.single.containsKey('Email'), isFalse);
    });

    test(
      'GivenAnEnvelopeWithoutPaging_WhenPersonsListed_ThenTheRequestFillsIt',
      () async {
        // Given
        final repository = repositoryAnswering(emptyPage);

        // When
        final result = await repository.listScopePersons(
          scopeId: 'scope-1',
          pageNumber: 2,
          pageSize: 30,
        );

        // Then
        final page = result.valueOrNull!;
        expect(page.items, isEmpty);
        expect(page.pageNumber, 2);
        expect(page.pageSize, 30);
        expect(page.totalItems, 0);
        expect(page.totalPages, 1);
      },
    );

    test(
      'GivenSuccessFalse_WhenPersonsListed_ThenValidationErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await repository.listScopePersons(scopeId: 'scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test('GivenA404_WhenPersonsListed_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(404));

      // When
      final result = await repository.listScopePersons(scopeId: 'gone');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    test(
      'GivenNoConnection_WhenPersonsListed_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.listScopePersons(scopeId: 'scope-1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('listScopeAdmins', () {
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
        adapter.uris.single.queryParameters.containsKey(
          'ExcludeOwnersOfScopeId',
        ),
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

    test(
      'GivenFiltersAndPaging_WhenScopeAdminsListed_ThenTheyTravelTrimmed',
      () async {
        // Given
        final repository = repositoryAnswering(emptyPage);

        // When
        await repository.listScopeAdmins(
          name: ' Ada ',
          email: '  ada@example.com',
          excludeOwnersOfScopeId: ' scope-1 ',
          pageNumber: 3,
          pageSize: 50,
        );

        // Then
        expect(adapter.methods.single, 'GET');
        expect(adapter.paths.single, '/api/persons/scope-admins');
        expect(adapter.queries.single, <String, dynamic>{
          'Name': 'Ada',
          'Email': 'ada@example.com',
          'ExcludeOwnersOfScopeId': 'scope-1',
          'PageNumber': 3,
          'PageSize': 50,
        });
      },
    );

    test(
      'GivenNoArguments_WhenScopeAdminsListed_ThenOnlyThePagingIsSent',
      () async {
        // Given
        final repository = repositoryAnswering(emptyPage);

        // When
        await repository.listScopeAdmins();

        // Then
        expect(adapter.queries.single, <String, dynamic>{
          'PageNumber': 1,
          'PageSize': 20,
        });
      },
    );

    test('GivenABlankEmail_WhenScopeAdminsListed_ThenNoEmailIsSent', () async {
      // Given
      final repository = repositoryAnswering(emptyPage);

      // When
      await repository.listScopeAdmins(email: '  ');

      // Then
      expect(adapter.queries.single.containsKey('Email'), isFalse);
    });

    test(
      'GivenAPagedAnswer_WhenScopeAdminsListed_ThenThePagingIsMapped',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'person-1',
                  'name': 'Ada',
                  'email': 'ada@example.com',
                },
              ],
              'pageNumber': 3,
              'pageSize': 10,
              'totalItems': 21,
              'totalPages': 3,
            },
          ),
        );

        // When
        final result = await repository.listScopeAdmins();

        // Then
        final page = result.valueOrNull!;
        expect(page.items.single.id, 'person-1');
        expect(page.pageNumber, 3);
        expect(page.pageSize, 10);
        expect(page.totalItems, 21);
        expect(page.totalPages, 3);
      },
    );

    test(
      'GivenASummaryWithNoFields_WhenScopeAdminsListed_ThenEmptyStringsAreUsed',
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
        final result = await repository.listScopeAdmins();

        // Then
        final item = result.valueOrNull!.items.single;
        expect(item.id, '');
        expect(item.name, '');
        expect(item.email, '');
      },
    );

    test('GivenAnEnvelopeWithoutPaging_WhenScopeAdminsListed_ThenTheRequestAndItemsFillIt', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'a'},
              <String, dynamic>{'id': 'b'},
            ],
          },
        ),
      );

      // When
      final result = await repository.listScopeAdmins(
        pageNumber: 4,
        pageSize: 5,
      );

      // Then
      final page = result.valueOrNull!;
      expect(page.items.map((item) => item.id), <String>['a', 'b']);
      expect(page.pageNumber, 4);
      expect(page.pageSize, 5);
      expect(page.totalItems, 2);
      expect(page.totalPages, 1);
    });

    test('GivenNoData_WhenScopeAdminsListed_ThenThePageIsEmpty', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.listScopeAdmins();

      // Then
      final page = result.valueOrNull!;
      expect(page.items, isEmpty);
      expect(page.totalItems, 0);
      expect(page.totalPages, 1);
    });

    test(
      'GivenSuccessFalse_WhenScopeAdminsListed_ThenValidationErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await repository.listScopeAdmins();

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test('GivenSuccessFalseWithoutErrors_WhenScopeAdminsListed_ThenNoErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refusedWithoutReason);

      // When
      final result = await repository.listScopeAdmins();

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, isEmpty);
    });

    // A Scope Admin who may not manage the named scope is refused, and the
    // picker falls back to an identifier.
    test('GivenAScopeTheCallerMayNotManage_WhenScopeAdminsListed_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await repository.listScopeAdmins(
        excludeOwnersOfScopeId: 'scope-1',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
      expect(result.failureOrNull?.errors, <String>['Refused by status.']);
    });
  });

  group('listSystemAdmins', () {
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

    test('GivenSuccessFalse_WhenSystemAdminsListed_ThenValidationErrorsAreReturned', () async {
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
    });

    test('GivenPaddedFiltersAndPaging_WhenSystemAdminsListed_ThenAGetCarriesThemTrimmed', () async {
      // Given
      final repository = repositoryAnswering(emptyPage);

      // When
      await repository.listSystemAdmins(
        name: '  Ada ',
        email: ' ada@example.com ',
        pageNumber: 2,
        pageSize: 40,
      );

      // Then
      expect(adapter.methods.single, 'GET');
      expect(adapter.queries.single, <String, dynamic>{
        'Name': 'Ada',
        'Email': 'ada@example.com',
        'PageNumber': 2,
        'PageSize': 40,
      });
    });

    test('GivenAnEnvelopeWithoutPaging_WhenSystemAdminsListed_ThenTheRequestFillsIt', () async {
      // Given
      final repository = repositoryAnswering(emptyPage);

      // When
      final result = await repository.listSystemAdmins(
        pageNumber: 3,
        pageSize: 15,
      );

      // Then
      final page = result.valueOrNull!;
      expect(page.items, isEmpty);
      expect(page.pageNumber, 3);
      expect(page.pageSize, 15);
      expect(page.totalItems, 0);
      expect(page.totalPages, 1);
    });

    test(
      'GivenNoConnection_WhenSystemAdminsListed_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.listSystemAdmins();

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('addScopeOwner', () {
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

    test(
      'GivenASystemAdminsAdd_WhenTheApiAdds_ThenTheOutcomeIsAdded',
      () async {
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
      },
    );

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

    test(
      'GivenAnExistingOwner_WhenAdded_ThenTheOutcomeIsAlreadyOwner',
      () async {
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
      },
    );

    test(
      'GivenAScopeAndAPerson_WhenOwnerAdded_ThenAPostAddressesThem',
      () async {
        // Given
        final repository = repositoryAnswering(acknowledged);

        // When
        await repository.addScopeOwner(scopeId: 's1', personId: 'p7');

        // Then
        expect(adapter.methods.single, 'POST');
        expect(adapter.paths.single, '/api/scopes/s1/owners/p7');
      },
    );

    test('GivenNoData_WhenOwnerAdded_ThenTheOutcomeIsAdded', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      final result = await repository.addScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.valueOrNull, AddOwnerOutcome.added);
    });

    test(
      'GivenInvitedAndAlreadyOwner_WhenOwnerAdded_ThenTheOutcomeIsInvited',
      () async {
        // Given
        final repository = repositoryAnswering(
          answeringData(const <String, dynamic>{
            'alreadyOwner': true,
            'invited': true,
          }),
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

    // AF-14b and AF-14c — not a Scope Admin, or already an owner.
    test('GivenARefusal_WhenOwnerAdded_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.addScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['The API refused this.']);
    });

    test(
      'GivenSuccessFalseWithoutErrors_WhenOwnerAdded_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.addScopeOwner(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenA403_WhenOwnerAdded_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await repository.addScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test('GivenA404_WhenOwnerAdded_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(404));

      // When
      final result = await repository.addScopeOwner(
        scopeId: 's1',
        personId: 'gone',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    test(
      'GivenNoConnection_WhenOwnerAdded_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.addScopeOwner(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('removeScopeOwner', () {
    test(
      'GivenAnOwner_WhenRemoved_ThenADeleteAddressesTheScopeAndPerson',
      () async {
        // Given
        final repository = repositoryAnswering(acknowledged);

        // When
        final result = await repository.removeScopeOwner(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(adapter.methods.single, 'DELETE');
        expect(adapter.paths.single, '/api/scopes/s1/owners/p7');
      },
    );

    // AF-14a — a scope may not be left without an owner.
    test('GivenTheLastOwner_WhenRemoved_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.removeScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['The API refused this.']);
    });

    test(
      'GivenSuccessFalseWithoutErrors_WhenRemoved_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.removeScopeOwner(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenA403_WhenRemoved_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(403));

      // When
      final result = await repository.removeScopeOwner(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test(
      'GivenNoConnection_WhenRemoved_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.removeScopeOwner(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('promoteScopeUser', () {
    test(
      'GivenAUser_WhenPromoted_ThenAPostAddressesTheScopeAndPerson',
      () async {
        // Given
        final repository = repositoryAnswering(acknowledged);

        // When
        final result = await repository.promoteScopeUser(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(adapter.methods.single, 'POST');
        expect(adapter.paths.single, '/api/scopes/s1/users/p7/promote');
      },
    );

    test('GivenARefusal_WhenPromoted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.promoteScopeUser(
        scopeId: 's1',
        personId: 'p7',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['The API refused this.']);
    });

    test(
      'GivenSuccessFalseWithoutErrors_WhenPromoted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.promoteScopeUser(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenA404_WhenPromoted_ThenNotFoundIsReturned', () async {
      // Given
      final repository = repositoryAnswering(answeringStatus(404));

      // When
      final result = await repository.promoteScopeUser(
        scopeId: 's1',
        personId: 'gone',
      );

      // Then
      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    test(
      'GivenNoConnection_WhenPromoted_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.promoteScopeUser(
          scopeId: 's1',
          personId: 'p7',
        );

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });

  group('sendVerificationEmail', () {
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

    test('GivenAPerson_WhenAVerificationEmailIsSent_ThenItIsAPost', () async {
      // Given
      final repository = repositoryAnswering(acknowledged);

      // When
      await repository.sendVerificationEmail('p1');

      // Then
      expect(adapter.methods.single, 'POST');
    });

    test(
      'GivenARefusal_WhenAVerificationEmailIsSent_ThenApiErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refused);

        // When
        final result = await repository.sendVerificationEmail('p1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, <String>['The API refused this.']);
      },
    );

    test('GivenSuccessFalseWithoutErrors_WhenAVerificationEmailIsSent_ThenNoErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refusedWithoutReason);

      // When
      final result = await repository.sendVerificationEmail('p1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, isEmpty);
    });

    test(
      'GivenACooldown_WhenAVerificationEmailIsSent_ThenTheFailureIsRateLimited',
      () async {
        // Given
        final repository = repositoryAnswering(answeringStatus(429));

        // When
        final result = await repository.sendVerificationEmail('p1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.rateLimited);
        expect(result.failureOrNull?.errors, <String>['Refused by status.']);
      },
    );

    test('GivenNoConnection_WhenAVerificationEmailIsSent_ThenNetworkFailureIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.sendVerificationEmail('p1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('sendPasswordReset', () {
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

    test('GivenAPerson_WhenAResetIsSent_ThenItIsAPost', () async {
      // Given
      final repository = repositoryAnswering(acknowledged);

      // When
      await repository.sendPasswordReset('p1');

      // Then
      expect(adapter.methods.single, 'POST');
    });

    test('GivenARefusal_WhenAResetIsSent_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.sendPasswordReset('p1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['The API refused this.']);
    });

    test(
      'GivenSuccessFalseWithoutErrors_WhenAResetIsSent_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.sendPasswordReset('p1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenNoConnection_WhenAResetIsSent_ThenNetworkFailureIsReturned',
      () async {
        // Given
        final repository = repositoryAnswering(noConnection);

        // When
        final result = await repository.sendPasswordReset('p1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.network);
      },
    );
  });
}
