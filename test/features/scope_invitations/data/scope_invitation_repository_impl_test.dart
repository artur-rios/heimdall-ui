import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scope_invitations/data/scope_invitation_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiScopeInvitationRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiScopeInvitationRepository(ScopeInvitationClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  const notOpen = 'The invitation was not found or is no longer open.';

  test(
    'GivenAScopesInvitations_WhenListed_ThenTheyAreAskedForAndMapped',
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
                'id': 'i1',
                'inviteeId': 'p7',
                'inviteeName': 'Hedy Lamarr',
                'inviteeEmail': 'hedy@example.com',
                'invitedByName': 'Ada',
                'createdAt': '2026-10-16T09:00:00Z',
                'expiresAt': '2026-10-23T09:00:00Z',
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
      final result = await repository.listForScope('s1');

      // Then
      expect(adapter.paths.single, '/api/scopes/s1/owner-invitations');
      expect(adapter.methods.single, 'GET');
      final item = result.valueOrNull!.items.single;
      expect(item.id, 'i1');
      expect(item.inviteeName, 'Hedy Lamarr');
      expect(item.inviteeEmail, 'hedy@example.com');
      expect(item.invitedByName, 'Ada');
      expect(item.expiresAt, DateTime.utc(2026, 10, 23, 9));
    },
  );

  test(
    'GivenAnInvitation_WhenWithdrawn_ThenItIsAddressedAndNoContentIsASuccess',
    () async {
      // Given — the API answers 204 with no body
      final repository = repositoryAnswering(const StubAnswer(status: 204));

      // When
      final result = await repository.withdraw('s1', 'i1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.paths.single, '/api/scopes/s1/owner-invitations/i1');
      expect(adapter.methods.single, 'DELETE');
    },
  );

  test(
    'GivenAnEndedInvitation_WhenWithdrawn_ThenNotFoundCarriesTheApiMessage',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>[notOpen],
          },
        ),
      );

      // When
      final result = await repository.withdraw('s1', 'i1');

      // Then
      expect(result.failureOrNull!.kind, FailureKind.notFound);
      expect(result.failureOrNull!.errors, <String>[notOpen]);
    },
  );

  test('GivenMyInvitations_WhenListed_ThenTheyAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'i1',
              'scopeId': 's1',
              'scopeName': 'Acme',
              'invitedByName': null,
              'createdAt': '2026-10-16T09:00:00Z',
              'expiresAt': '2026-10-23T09:00:00Z',
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
    final result = await repository.listMine();

    // Then
    expect(adapter.paths.single, '/api/persons/me/scope-invitations');
    final item = result.valueOrNull!.items.single;
    expect(item.scopeName, 'Acme');
    expect(item.invitedByName, isNull);
  });

  test('GivenAnInvitation_WhenAccepted_ThenItIsPosted', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'messages': <String>['The invitation was accepted.'],
          'data': <String, dynamic>{'id': 'i1', 'scopeId': 's1'},
        },
      ),
    );

    // When
    final result = await repository.accept('i1');

    // Then
    expect(result.isSuccess, isTrue);
    expect(adapter.paths.single, '/api/scope-invitations/i1/accept');
    expect(adapter.methods.single, 'POST');
  });

  test(
    'GivenAnEndedInvitation_WhenDeclined_ThenNotFoundCarriesTheApiMessage',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>[notOpen],
          },
        ),
      );

      // When
      final result = await repository.decline('i1');

      // Then
      expect(adapter.paths.single, '/api/scope-invitations/i1/decline');
      expect(result.failureOrNull!.kind, FailureKind.notFound);
      expect(result.failureOrNull!.errors, <String>[notOpen]);
    },
  );

  const refused = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>[notOpen],
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

  const ended = StubAnswer(
    status: 404,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>[notOpen],
    },
  );

  const noConnection = StubAnswer(status: 0);

  group('listForScope', () {
    const ownerInvitation = <String, dynamic>{
      'id': 'i1',
      'inviteeId': 'p7',
      'inviteeName': 'Hedy Lamarr',
      'inviteeEmail': 'hedy@example.com',
      'invitedByName': 'Ada',
      'createdAt': '2026-10-16T09:00:00Z',
      'expiresAt': '2026-10-23T09:00:00Z',
    };

    test('GivenNoPaging_WhenListed_ThenTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      await repository.listForScope('s1');

      // Then
      expect(adapter.queries.single, <String, dynamic>{
        'PageNumber': 1,
        'PageSize': 50,
      });
    });

    test('GivenPaging_WhenListed_ThenItTravelsAsQueryParameters', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      await repository.listForScope('s1', pageNumber: 3, pageSize: 10);

      // Then
      expect(adapter.queries.single, <String, dynamic>{
        'PageNumber': 3,
        'PageSize': 10,
      });
    });

    test(
      'GivenAPageOfInvitations_WhenListed_ThenEveryFieldAndThePagingAreMapped',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <Map<String, dynamic>>[ownerInvitation],
              'pageNumber': 2,
              'pageSize': 10,
              'totalItems': 11,
              'totalPages': 2,
            },
          ),
        );

        // When
        final result = await repository.listForScope('s1');

        // Then
        final page = result.valueOrNull!;
        final item = page.items.single;
        expect(item.inviteeId, 'p7');
        expect(item.createdAt, DateTime.utc(2026, 10, 16, 9));
        expect(page.pageNumber, 2);
        expect(page.pageSize, 10);
        expect(page.totalItems, 11);
        expect(page.totalPages, 2);
        expect(page.hasNextPage, isFalse);
      },
    );

    test(
      'GivenAnInvitationWithNoFields_WhenListed_ThenTheDefaultsAreUsed',
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
        final result = await repository.listForScope('s1');

        // Then
        final item = result.valueOrNull!.items.single;
        expect(item.id, '');
        expect(item.inviteeId, '');
        expect(item.inviteeName, '');
        expect(item.inviteeEmail, '');
        expect(item.invitedByName, isNull);
        expect(item.createdAt, isNull);
        expect(item.expiresAt, isNull);
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
              'data': <Map<String, dynamic>>[ownerInvitation, ownerInvitation],
            },
          ),
        );

        // When
        final result = await repository.listForScope(
          's1',
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
      final result = await repository.listForScope('s1');

      // Then
      expect(result.valueOrNull?.items, isEmpty);
      expect(result.valueOrNull?.totalItems, 0);
    });

    test('GivenARefusal_WhenListed_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.listForScope('s1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[notOpen]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenListed_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.listForScope('s1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenAScopeNotOwned_WhenListed_ThenForbiddenIsReturned', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 403,
          body: <String, dynamic>{'success': false, 'errors': <String>[]},
        ),
      );

      // When
      final result = await repository.listForScope('s1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test('GivenNoConnection_WhenListed_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.listForScope('s1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('withdraw', () {
    test('GivenNoConnection_WhenWithdrawn_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.withdraw('s1', 'i1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('listMine', () {
    const myInvitation = <String, dynamic>{
      'id': 'i1',
      'scopeId': 's1',
      'scopeName': 'Acme',
      'invitedByName': 'Ada',
      'createdAt': '2026-10-16T09:00:00Z',
      'expiresAt': '2026-10-23T09:00:00Z',
    };

    test('GivenNoPaging_WhenListed_ThenTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      await repository.listMine();

      // Then
      expect(adapter.methods.single, 'GET');
      expect(adapter.queries.single, <String, dynamic>{
        'PageNumber': 1,
        'PageSize': 50,
      });
    });

    test('GivenPaging_WhenListed_ThenItTravelsAsQueryParameters', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      await repository.listMine(pageNumber: 2, pageSize: 25);

      // Then
      expect(adapter.queries.single, <String, dynamic>{
        'PageNumber': 2,
        'PageSize': 25,
      });
    });

    test(
      'GivenAPageOfInvitations_WhenListed_ThenEveryFieldAndThePagingAreMapped',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <Map<String, dynamic>>[myInvitation],
              'pageNumber': 1,
              'pageSize': 10,
              'totalItems': 11,
              'totalPages': 2,
            },
          ),
        );

        // When
        final result = await repository.listMine();

        // Then
        final page = result.valueOrNull!;
        final item = page.items.single;
        expect(item.id, 'i1');
        expect(item.scopeId, 's1');
        expect(item.scopeName, 'Acme');
        expect(item.invitedByName, 'Ada');
        expect(item.createdAt, DateTime.utc(2026, 10, 16, 9));
        expect(item.expiresAt, DateTime.utc(2026, 10, 23, 9));
        expect(page.pageNumber, 1);
        expect(page.pageSize, 10);
        expect(page.totalItems, 11);
        expect(page.totalPages, 2);
        expect(page.hasNextPage, isTrue);
      },
    );

    test(
      'GivenAnInvitationWithNoFields_WhenListed_ThenTheDefaultsAreUsed',
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
        final result = await repository.listMine();

        // Then
        final item = result.valueOrNull!.items.single;
        expect(item.id, '');
        expect(item.scopeId, '');
        expect(item.scopeName, '');
        expect(item.invitedByName, isNull);
        expect(item.createdAt, isNull);
        expect(item.expiresAt, isNull);
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
              'data': <Map<String, dynamic>>[myInvitation, myInvitation],
            },
          ),
        );

        // When
        final result = await repository.listMine(pageNumber: 4, pageSize: 5);

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
      final result = await repository.listMine();

      // Then
      expect(result.valueOrNull?.items, isEmpty);
      expect(result.valueOrNull?.totalItems, 0);
    });

    test('GivenARefusal_WhenListed_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.listMine();

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[notOpen]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenListed_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.listMine();

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenListed_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.listMine();

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('accept', () {
    // Nothing in the answer is read: the envelope's success is the outcome.
    test(
      'GivenAnAcknowledgementWithoutData_WhenAccepted_ThenItIsASuccess',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.accept('i1');

        // Then
        expect(result.isSuccess, isTrue);
      },
    );

    test('GivenARefusal_WhenAccepted_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.accept('i1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[notOpen]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenAccepted_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.accept('i1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test(
      'GivenAnEndedInvitation_WhenAccepted_ThenNotFoundCarriesTheApiMessage',
      () async {
        // Given
        final repository = repositoryAnswering(ended);

        // When
        final result = await repository.accept('i1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.notFound);
        expect(result.failureOrNull?.errors, <String>[notOpen]);
      },
    );

    test('GivenNoConnection_WhenAccepted_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.accept('i1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('decline', () {
    test('GivenAnInvitation_WhenDeclined_ThenItIsPosted', () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{'id': 'i1'},
          },
        ),
      );

      // When
      final result = await repository.decline('i1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.methods.single, 'POST');
      expect(adapter.paths.single, '/api/scope-invitations/i1/decline');
    });

    test('GivenARefusal_WhenDeclined_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.decline('i1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[notOpen]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenDeclined_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.decline('i1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenDeclined_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.decline('i1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });
}
