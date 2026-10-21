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
}
