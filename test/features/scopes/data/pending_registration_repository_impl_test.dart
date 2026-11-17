import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/data/pending_registration_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiPendingRegistrationRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiPendingRegistrationRepository(ScopeClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenAPage_WhenListed_ThenItIsAskedForAndMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'r1',
              'name': 'Ada Lovelace',
              'email': 'ada@example.com',
              'createdAt': '2026-10-13T09:00:00Z',
              'expiresAt': '2026-10-14T09:00:00Z',
              'attemptsLeft': 7,
              'expired': true,
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
    final result = await repository.list('s1', pageNumber: 2);

    // Then
    expect(adapter.paths.single, '/api/scopes/s1/pending-registrations');
    expect(adapter.methods.single, 'GET');
    expect(adapter.queries.single, <String, dynamic>{
      'PageNumber': 2,
      'PageSize': 20,
    });
    final item = result.valueOrNull!.items.single;
    expect(item.email, 'ada@example.com');
    expect(item.attemptsLeft, 7);
    expect(item.expired, isTrue);
    expect(item.expiresAt, DateTime.utc(2026, 10, 14, 9));
  });

  test(
    'GivenARegistration_WhenDiscarded_ThenItsScopeAndIdAreAddressed',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{'id': 'r1'},
          },
        ),
      );

      // When
      final result = await repository.discard('s1', 'r1');

      // Then
      expect(result.isSuccess, isTrue);
      expect(adapter.paths.single, '/api/scopes/s1/pending-registrations/r1');
      expect(adapter.methods.single, 'DELETE');
    },
  );

  test(
    'GivenAGoneRegistration_WhenDiscarded_ThenTheFailureIsNotFound',
    () async {
      // Given — AF-35d
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 404,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Pending registration not found.'],
          },
        ),
      );

      // When
      final result = await repository.discard('s1', 'r1');

      // Then
      expect(result.failureOrNull!.kind, FailureKind.notFound);
      expect(result.failureOrNull!.errors, <String>[
        'Pending registration not found.',
      ]);
    },
  );

  const registration = <String, dynamic>{
    'id': 'r1',
    'name': 'Ada Lovelace',
    'email': 'ada@example.com',
    'createdAt': '2026-10-13T09:00:00Z',
    'expiresAt': '2026-10-14T09:00:00Z',
    'attemptsLeft': 7,
    'expired': true,
  };

  const refused = StubAnswer(
    status: 200,
    body: <String, dynamic>{
      'success': false,
      'errors': <String>['Pending registration not found.'],
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

  const noConnection = StubAnswer(status: 0);

  group('list', () {
    test('GivenNoPaging_WhenListed_ThenTheDefaultsAreSent', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      await repository.list('s1');

      // Then
      expect(adapter.queries.single, <String, dynamic>{
        'PageNumber': 1,
        'PageSize': 20,
      });
    });

    test('GivenAPageSize_WhenListed_ThenItTravelsAsAQueryParameter', () async {
      // Given
      final repository = repositoryAnswering(noData);

      // When
      await repository.list('s1', pageSize: 5);

      // Then
      expect(adapter.queries.single, containsPair('PageSize', 5));
    });

    test(
      'GivenAPage_WhenListed_ThenTheRemainingFieldsAndThePagingAreMapped',
      () async {
        // Given
        final repository = repositoryAnswering(
          const StubAnswer(
            status: 200,
            body: <String, dynamic>{
              'success': true,
              'data': <Map<String, dynamic>>[registration],
              'pageNumber': 2,
              'pageSize': 10,
              'totalItems': 11,
              'totalPages': 2,
            },
          ),
        );

        // When
        final result = await repository.list('s1');

        // Then
        final page = result.valueOrNull!;
        final item = page.items.single;
        expect(item.id, 'r1');
        expect(item.name, 'Ada Lovelace');
        expect(item.createdAt, DateTime.utc(2026, 10, 13, 9));
        expect(page.pageNumber, 2);
        expect(page.pageSize, 10);
        expect(page.totalItems, 11);
        expect(page.totalPages, 2);
      },
    );

    test(
      'GivenARegistrationWithNoFields_WhenListed_ThenTheDefaultsAreUsed',
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
        final result = await repository.list('s1');

        // Then
        final item = result.valueOrNull!.items.single;
        expect(item.id, '');
        expect(item.name, '');
        expect(item.email, '');
        expect(item.createdAt, isNull);
        expect(item.expiresAt, isNull);
        expect(item.attemptsLeft, 0);
        expect(item.expired, isFalse);
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
              'data': <Map<String, dynamic>>[registration, registration],
            },
          ),
        );

        // When
        final result = await repository.list('s1', pageNumber: 4, pageSize: 5);

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
      final result = await repository.list('s1');

      // Then
      expect(result.valueOrNull?.items, isEmpty);
      expect(result.valueOrNull?.totalItems, 0);
    });

    test('GivenARefusal_WhenListed_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.list('s1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'Pending registration not found.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenListed_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.list('s1');

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
      final result = await repository.list('s1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.forbidden);
    });

    test('GivenNoConnection_WhenListed_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.list('s1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('discard', () {
    // Nothing in the answer is read: the envelope's success is the outcome.
    test(
      'GivenAnAcknowledgementWithoutData_WhenDiscarded_ThenItIsASuccess',
      () async {
        // Given
        final repository = repositoryAnswering(noData);

        // When
        final result = await repository.discard('s1', 'r1');

        // Then
        expect(result.isSuccess, isTrue);
      },
    );

    test('GivenARefusal_WhenDiscarded_ThenApiErrorsAreReturned', () async {
      // Given
      final repository = repositoryAnswering(refused);

      // When
      final result = await repository.discard('s1', 'r1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>[
        'Pending registration not found.',
      ]);
    });

    test(
      'GivenARefusalWithoutErrors_WhenDiscarded_ThenNoErrorsAreReturned',
      () async {
        // Given
        final repository = repositoryAnswering(refusedWithoutReason);

        // When
        final result = await repository.discard('s1', 'r1');

        // Then
        expect(result.failureOrNull?.kind, FailureKind.validation);
        expect(result.failureOrNull?.errors, isEmpty);
      },
    );

    test('GivenNoConnection_WhenDiscarded_ThenNetworkIsReturned', () async {
      // Given
      final repository = repositoryAnswering(noConnection);

      // When
      final result = await repository.discard('s1', 'r1');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });
}
