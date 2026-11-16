import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/erasure_requests/data/erasure_request_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiErasureRequestRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiErasureRequestRepository(AuthClient(dio));
  }

  const emptyPage = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <Map<String, dynamic>>[],
      'pageNumber': 1,
      'pageSize': 20,
      'totalItems': 0,
      'totalPages': 0,
    },
  );

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAPage_WhenListed_ThenRequestsAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'subjectId': '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
              'isGoogleUser': true,
              'requestedAt': '2026-09-01T10:00:00Z',
              'dueAt': '2026-10-01T10:00:00Z',
              'overdue': true,
              'blockedReason': 'The subject is the last owner of a scope.',
            },
          ],
          'pageNumber': 1,
          'pageSize': 20,
          'totalItems': 1,
          'totalPages': 1,
        },
      ),
    );

    // When
    final result = await repository.list();

    // Then
    final item = result.valueOrNull!.items.single;
    expect(item.isGoogleUser, isTrue);
    expect(item.overdue, isTrue);
    expect(item.dueAt, DateTime.utc(2026, 10, 1, 10));
    expect(item.blockedReason, 'The subject is the last owner of a scope.');
  });

  test('GivenOverdueOnly_WhenListed_ThenTheFilterTravels', () async {
    // Given
    final repository = repositoryAnswering(emptyPage);

    // When
    await repository.list(overdueOnly: true, pageNumber: 2);

    // Then
    expect(adapter.queries.single['OverdueOnly'], true);
    expect(adapter.queries.single['PageNumber'], 2);
  });

  test('GivenAScopeAdmin_WhenListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 403,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Forbidden.'],
        },
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull!.kind, FailureKind.forbidden);
    expect(result.failureOrNull!.errors, <String>['Forbidden.']);
  });

  test('GivenIds_WhenReapplied_ThenTheyTravelAndTheOutcomeIsMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'anonymised': 1,
            'alreadyAnonymised': 2,
            'notFound': <String>['0a9b8c7d-6e5f-4a3b-8c2d-1e0f9a8b7c6d'],
          },
        },
      ),
    );

    // When
    final result = await repository.reapply(<String>[
      '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
    ]);

    // Then
    expect(adapter.bodies.single, <String, dynamic>{
      'subjectIds': <String>['6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c'],
    });
    expect(result.valueOrNull!.anonymised, 1);
    expect(result.valueOrNull!.alreadyAnonymised, 2);
    expect(result.valueOrNull!.notFound, hasLength(1));
  });

  test(
    'GivenARefusedReconciliation_WhenReapplied_ThenApiErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 400,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['At least one subject identifier is required.'],
          },
        ),
      );

      // When
      final result = await repository.reapply(const <String>['x']);

      // Then
      expect(result.failureOrNull!.errors, <String>[
        'At least one subject identifier is required.',
      ]);
    },
  );

  test('GivenNoConnection_WhenListed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull!.kind, FailureKind.network);
  });

  const refusedInEnvelope = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['Refused by the API.'],
    },
  );

  const refusedWithoutReason = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': false},
  );

  const acceptedWithoutData = StubAnswer(
    status: 200,
    body: <String, dynamic>{'success': true, 'errors': <String>[]},
  );

  test('GivenNoArguments_WhenListed_ThenTheDefaultsTravel', () async {
    // Given
    final repository = repositoryAnswering(emptyPage);

    // When
    await repository.list();

    // Then
    expect(adapter.methods.single, 'GET');
    expect(adapter.paths.single, '/api/auth/erasure-requests');
    expect(adapter.queries.single['OverdueOnly'], false);
    expect(adapter.queries.single['PageNumber'], 1);
    expect(adapter.queries.single['PageSize'], 20);
  });

  test('GivenAPageSize_WhenListed_ThenItTravels', () async {
    // Given
    final repository = repositoryAnswering(emptyPage);

    // When
    await repository.list(pageSize: 50);

    // Then
    expect(adapter.queries.single['PageSize'], 50);
  });

  test('GivenAPage_WhenListed_ThenTheRestOfTheRequestIsMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'subjectId': '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
              'isGoogleUser': false,
              'requestedAt': '2026-09-01T10:00:00Z',
              'dueAt': '2026-10-01T10:00:00Z',
              'overdue': false,
              'blockedReason': null,
            },
          ],
          'pageNumber': 2,
          'pageSize': 1,
          'totalItems': 3,
          'totalPages': 3,
        },
      ),
    );

    // When
    final result = await repository.list(pageNumber: 2, pageSize: 1);

    // Then
    final page = result.valueOrNull!;
    final item = page.items.single;
    expect(item.subjectId, '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c');
    expect(item.isGoogleUser, isFalse);
    expect(item.requestedAt, DateTime.utc(2026, 9, 1, 10));
    expect(item.overdue, isFalse);
    expect(item.blockedReason, isNull);
    expect(page.pageNumber, 2);
    expect(page.pageSize, 1);
    expect(page.totalItems, 3);
    expect(page.totalPages, 3);
  });

  test(
    'GivenARequestWithoutFields_WhenListed_ThenTheFallbacksAreUsed',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <Map<String, dynamic>>[<String, dynamic>{}],
          },
        ),
      );

      // When
      final result = await repository.list();

      // Then
      final item = result.valueOrNull!.items.single;
      expect(item.subjectId, '');
      expect(item.isGoogleUser, isFalse);
      expect(item.requestedAt, isNull);
      expect(item.dueAt, isNull);
      expect(item.overdue, isFalse);
      expect(item.blockedReason, isNull);
    },
  );

  test('GivenABlankBlockedReason_WhenListed_ThenNoReasonIsKept', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'subjectId': 's1', 'blockedReason': '  '},
          ],
        },
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.valueOrNull!.items.single.blockedReason, isNull);
  });

  test(
    'GivenAnAnswerWithoutPaging_WhenListed_ThenTheRequestedPagingIsKept',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'subjectId': 's1'},
              <String, dynamic>{'subjectId': 's2'},
            ],
          },
        ),
      );

      // When
      final result = await repository.list(pageNumber: 3, pageSize: 10);

      // Then
      final page = result.valueOrNull!;
      expect(page.pageNumber, 3);
      expect(page.pageSize, 10);
      expect(page.totalItems, 2);
      expect(page.totalPages, 1);
    },
  );

  test('GivenAnAnswerWithoutData_WhenListed_ThenThePageIsEmpty', () async {
    // Given
    final repository = repositoryAnswering(acceptedWithoutData);

    // When
    final result = await repository.list();

    // Then
    expect(result.valueOrNull!.items, isEmpty);
    expect(result.valueOrNull!.totalItems, 0);
  });

  test('GivenARefusalWithinA200_WhenListed_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(refusedInEnvelope);

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull!.kind, FailureKind.validation);
    expect(result.failureOrNull!.errors, <String>['Refused by the API.']);
  });

  test(
    'GivenARefusalWithoutReason_WhenListed_ThenNoErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(refusedWithoutReason);

      // When
      final result = await repository.list();

      // Then
      expect(result.failureOrNull!.kind, FailureKind.validation);
      expect(result.failureOrNull!.errors, isEmpty);
    },
  );

  test('GivenIds_WhenReapplied_ThenTheyArePostedToTheReconciliation', () async {
    // Given
    final repository = repositoryAnswering(acceptedWithoutData);

    // When
    await repository.reapply(const <String>['s1', 's2']);

    // Then
    expect(adapter.methods.single, 'POST');
    expect(adapter.paths.single, '/api/auth/erasure-reconciliation');
    expect(adapter.requests.single, <String, dynamic>{
      'subjectIds': <String>['s1', 's2'],
    });
  });

  test(
    'GivenAnOutcomeWithoutCounts_WhenReapplied_ThenNothingIsCounted',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{},
          },
        ),
      );

      // When
      final result = await repository.reapply(const <String>['s1']);

      // Then
      final outcome = result.valueOrNull!;
      expect(outcome.anonymised, 0);
      expect(outcome.alreadyAnonymised, 0);
      expect(outcome.notFound, isEmpty);
    },
  );

  test(
    'GivenNoData_WhenReapplied_ThenAnIncompleteResponseIsReturned',
    () async {
      // Given
      final repository = repositoryAnswering(acceptedWithoutData);

      // When
      final result = await repository.reapply(const <String>['s1']);

      // Then
      expect(result.failureOrNull!.kind, FailureKind.unknown);
      expect(result.failureOrNull!.errors, <String>[
        'The API returned an incomplete response.',
      ]);
    },
  );

  test(
    'GivenARefusalWithinA200_WhenReapplied_ThenApiErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(refusedInEnvelope);

      // When
      final result = await repository.reapply(const <String>['s1']);

      // Then
      expect(result.failureOrNull!.kind, FailureKind.validation);
      expect(result.failureOrNull!.errors, <String>['Refused by the API.']);
    },
  );

  test(
    'GivenARefusalWithoutReason_WhenReapplied_ThenNoErrorsAreReturned',
    () async {
      // Given
      final repository = repositoryAnswering(refusedWithoutReason);

      // When
      final result = await repository.reapply(const <String>['s1']);

      // Then
      expect(result.failureOrNull!.kind, FailureKind.validation);
      expect(result.failureOrNull!.errors, isEmpty);
    },
  );

  test('GivenAScopeAdmin_WhenReapplied_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 403,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['Forbidden.'],
        },
      ),
    );

    // When
    final result = await repository.reapply(const <String>['s1']);

    // Then
    expect(result.failureOrNull!.kind, FailureKind.forbidden);
  });

  test(
    'GivenNoConnection_WhenReapplied_ThenNetworkFailureIsReturned',
    () async {
      // Given
      final repository = repositoryAnswering(const StubAnswer(status: 0));

      // When
      final result = await repository.reapply(const <String>['s1']);

      // Then
      expect(result.failureOrNull!.kind, FailureKind.network);
    },
  );
}
