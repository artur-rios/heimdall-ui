import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
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
}
