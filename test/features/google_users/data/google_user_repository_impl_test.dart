import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/google_users/data/google_user_repository_impl.dart';

import '../../../support/stub_adapter.dart';

void main() {
  late Dio dio;
  late StubAdapter adapter;

  ApiGoogleUserRepository repositoryAnswering(StubAnswer answer) {
    adapter = StubAdapter(answer);
    dio.httpClientAdapter = adapter;

    return ApiGoogleUserRepository(GoogleUserClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test(
    'GivenAScopeWithGoogleUsers_WhenCounted_ThenTheTotalIsReturned',
    () async {
      // Given
      final repository = repositoryAnswering(
        const StubAnswer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'google-1'},
            ],
            'totalItems': 12,
            'totalPages': 12,
          },
        ),
      );

      // When
      final result = await repository.countIn('scope-1');

      // Then
      expect(result.valueOrNull, 12);
    },
  );

  // The count is the envelope's own total, not how many rows came back.
  test('GivenAScopeWithGoogleUsers_WhenCounted_ThenOneRowIsAskedFor', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
          'totalItems': 12,
        },
      ),
    );

    // When
    await repository.countIn('scope-1');

    // Then
    expect(adapter.queries.single, containsPair('PageSize', 1));
  });

  test('GivenAScopeWithNoGoogleUsers_WhenCounted_ThenZeroIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[],
          'totalItems': 0,
        },
      ),
    );

    // When
    final result = await repository.countIn('scope-1');

    // Then
    expect(result.valueOrNull, 0);
  });

  test('GivenARefusedListing_WhenCounted_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const StubAnswer(
        status: 200,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['That scope is not yours.'],
        },
      ),
    );

    // When
    final result = await repository.countIn('scope-1');

    // Then
    expect(result.failureOrNull?.errors, <String>['That scope is not yours.']);
  });

  test('GivenNoConnection_WhenCounted_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const StubAnswer(status: 0));

    // When
    final result = await repository.countIn('scope-1');

    // Then
    expect(result.failureOrNull?.kind, FailureKind.network);
  });
}
