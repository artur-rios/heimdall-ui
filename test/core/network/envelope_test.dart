import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';

void main() {
  test('GivenSuccessfulEnvelope_WhenUnwrapped_ThenYieldsTheParsedData', () {
    // Given
    final json = <String, dynamic>{
      'success': true,
      'messages': <String>['Created'],
      'errors': <String>[],
      'data': <String, dynamic>{'name': 'Acme'},
    };

    // When
    final result = unwrapData<String>(
      json,
      (data) => (data! as Map<String, dynamic>)['name']! as String,
    );

    // Then
    expect(result.valueOrNull, 'Acme');
  });

  test(
    'GivenUnsuccessfulEnvelope_WhenUnwrapped_ThenYieldsAValidationFailure',
    () {
      // Given
      final json = <String, dynamic>{
        'success': false,
        'errors': <String>['Name already exists'],
        'data': null,
      };

      // When
      final result = unwrapData<String>(json, (data) => data! as String);

      // Then
      expect(result.failureOrNull?.kind, FailureKind.validation);
      expect(result.failureOrNull?.errors, <String>['Name already exists']);
    },
  );

  test('GivenPaginatedEnvelope_WhenUnwrapped_ThenCarriesItemsAndPaging', () {
    // Given
    final json = <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <dynamic>[
        <String, dynamic>{'name': 'Acme'},
        <String, dynamic>{'name': 'Globex'},
      ],
      'pageNumber': 1,
      'pageSize': 20,
      'totalItems': 2,
      'totalPages': 1,
    };

    // When
    final result = unwrapPage<String>(
      json,
      (item) => (item! as Map<String, dynamic>)['name']! as String,
    );

    // Then
    final page = result.valueOrNull!;
    expect(page.items, <String>['Acme', 'Globex']);
    expect(page.pageNumber, 1);
    expect(page.totalItems, 2);
    expect(page.hasNextPage, isFalse);
  });

  test('GivenMorePagesRemaining_WhenInspected_ThenHasNextPageIsTrue', () {
    // Given
    final json = <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <dynamic>[
        <String, dynamic>{'name': 'Acme'},
      ],
      'pageNumber': 1,
      'pageSize': 1,
      'totalItems': 3,
      'totalPages': 3,
    };

    // When
    final page = unwrapPage<String>(
      json,
      (item) => (item! as Map<String, dynamic>)['name']! as String,
    ).valueOrNull!;

    // Then
    expect(page.hasNextPage, isTrue);
  });

  test(
    'GivenUnauthorizedResponse_WhenMapped_ThenFailureKindIsUnauthorized',
    () {
      // Given
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/scopes'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/scopes'),
          statusCode: 401,
          data: <String, dynamic>{
            'errors': <String>['Token expired'],
          },
        ),
        type: DioExceptionType.badResponse,
      );

      // When
      final failure = failureFromDioException(error);

      // Then
      expect(failure.kind, FailureKind.unauthorized);
      expect(failure.errors, <String>['Token expired']);
    },
  );

  test('GivenServerError_WhenMapped_ThenFailureKindIsServer', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/scopes'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/scopes'),
        statusCode: 503,
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.server);
  });

  test('GivenConnectionTimeout_WhenMapped_ThenFailureKindIsNetwork', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/scopes'),
      type: DioExceptionType.connectionTimeout,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.network);
  });

  test('GivenResponseWithoutABody_WhenMapped_ThenErrorsAreEmpty', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/scopes'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/scopes'),
        statusCode: 404,
        data: 'not json',
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.notFound);
    expect(failure.errors, isEmpty);
  });
}
