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

  // A transport failure has no words of the API's own; Dio's are written for
  // developers ("The connection errored: …"), so a person is told what to do.
  for (final type in <DioExceptionType>[
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test(
      'GivenA${_capitalized(type.name)}_WhenMapped_ThenThePersonIsToldTheApiIsUnreachable',
      () {
        // Given
        final error = DioException(
          requestOptions: RequestOptions(path: '/api/scopes'),
          type: type,
          message: 'The connection errored: Connection refused',
        );

        // When
        final failure = failureFromDioException(error);

        // Then
        expect(failure.kind, FailureKind.network);
        expect(failure.message, kUnreachableMessage);
        expect(failure.displayMessage, kUnreachableMessage);
      },
    );
  }

  test('GivenAnUnknownErrorWithoutAResponse_WhenMapped_ThenThePersonIsToldTheApiIsUnreachable', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/scopes'),
      message: 'XMLHttpRequest onError callback was called',
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.network);
    expect(failure.message, kUnreachableMessage);
  });

  test(
    'GivenABadCertificateWithoutAResponse_WhenMapped_ThenFailureKindIsNetwork',
    () {
      // Given
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/scopes'),
        type: DioExceptionType.badCertificate,
      );

      // When
      final failure = failureFromDioException(error);

      // Then
      expect(failure.kind, FailureKind.network);
    },
  );

  test('GivenACancelledRequest_WhenMapped_ThenFailureKindIsNotNetwork', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/scopes'),
      type: DioExceptionType.cancel,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.unknown);
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

  // AF-02a and AF-09d — the API answers a mistyped code or password with 401,
  // and that is a rejection of the input, not of the session.
  test('GivenARefusedCredential_WhenMapped_ThenFailureKindIsValidation', () {
    // Given
    const message =
        'The code or recovery code is missing, incorrect, or already used.';
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/auth/2fa/verify'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/auth/2fa/verify'),
        statusCode: 401,
        data: <String, dynamic>{
          'success': false,
          'errors': <String>[message],
        },
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.validation);
    expect(failure.errors, <String>[message]);
  });

  // AF-08h, AF-09a, AF-09d, AF-09f, AF-30e — the one refusal the API now
  // gives every re-authentication, beside the older messages an earlier API
  // version may still send.
  for (final message in <String>[
    'The password or code is incorrect.',
    'The current password is incorrect.',
    'The code or recovery code is missing, incorrect, or already used.',
    'The credential presented was not accepted.',
  ]) {
    test(
      'GivenARefusedReauthentication_WhenMapped_ThenFailureKindIsValidation: '
      '$message',
      () {
        // Given
        final error = DioException(
          requestOptions: RequestOptions(path: '/api/auth/2fa/confirm'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/api/auth/2fa/confirm'),
            statusCode: 401,
            data: <String, dynamic>{
              'success': false,
              'errors': <String>[message],
            },
          ),
          type: DioExceptionType.badResponse,
        );

        // When
        final failure = failureFromDioException(error);

        // Then
        expect(failure.kind, FailureKind.validation);
        expect(failure.errors, <String>[message]);
        expect(rejectsSubmittedCredential(error.response?.data), isTrue);
      },
    );
  }

  // AF-02b — an expired challenge is still the end of it.
  test('GivenARefusedChallenge_WhenMapped_ThenFailureKindIsUnauthorized', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/auth/2fa/verify'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/auth/2fa/verify'),
        statusCode: 401,
        data: <String, dynamic>{
          'success': false,
          'errors': <String>[
            'The two-factor challenge is invalid or has expired. Log in again.',
          ],
        },
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.unauthorized);
  });

  test('GivenA429WithRetryAfter_WhenMapped_ThenTheHintNamesTheSeconds', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/auth/login'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        statusCode: 429,
        headers: Headers.fromMap(<String, List<String>>{
          'retry-after': <String>['37'],
        }),
        data: <String, dynamic>{
          'errors': <String>['Too many requests. Try again later.'],
        },
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.rateLimited);
    expect(failure.retryAfter, const Duration(seconds: 37));
    expect(failure.retryHint, 'Try again in 37 seconds.');
    expect(failure.errors, <String>['Too many requests. Try again later.']);
  });

  test('GivenA429WithoutRetryAfter_WhenMapped_ThenThereIsNoHint', () {
    // Given — a handler's 429, such as an account email's cooldown
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/persons/x/password-reset'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/persons/x/password-reset'),
        statusCode: 429,
        data: <String, dynamic>{
          'errors': <String>[
            'An email of this kind was sent to this person recently. Try again in a few minutes.',
          ],
        },
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.rateLimited);
    expect(failure.retryAfter, isNull);
    expect(failure.retryHint, isNull);
  });

  test('GivenAnUnreadableRetryAfter_WhenMapped_ThenItIsIgnored', () {
    // Given — an HTTP-date, or garbage, rather than whole seconds
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/auth/login'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        statusCode: 429,
        headers: Headers.fromMap(<String, List<String>>{
          'retry-after': <String>['Wed, 21 Oct 2026 07:28:00 GMT'],
        }),
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.rateLimited);
    expect(failure.retryAfter, isNull);
  });

  test('GivenARepeatedRetryAfter_WhenMapped_ThenTheFirstValueIsUsed', () {
    // Given — a proxy that adds its own header next to the API's
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/auth/resend-verification'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/auth/resend-verification'),
        statusCode: 429,
        headers: Headers.fromMap(<String, List<String>>{
          'retry-after': <String>['37', '120'],
        }),
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.rateLimited);
    expect(failure.retryAfter, const Duration(seconds: 37));
  });

  // FR-UX-09 — Retry-After is whole, non-negative seconds, and a wait beyond
  // a day is held to a day: the client pauses no longer than that, and never
  // with a duration that overflows. Anything else, zero included, pauses
  // nothing.
  for (final (raw, expected) in <(String?, Duration?)>[
    (null, null),
    ('', null),
    ('soon', null),
    ('3.5', null),
    ('+37', null),
    ('-5', null),
    ('0', null),
    ('000', null),
    ('0037', const Duration(seconds: 37)),
    ('999999999', const Duration(days: 1)),
    ('1000000000', const Duration(days: 1)),
    ('Wed, 21 Oct 2026 07:28:00 GMT', null),
    ('37', const Duration(seconds: 37)),
    (' 37 ', const Duration(seconds: 37)),
    ('86400', const Duration(days: 1)),
    ('86401', const Duration(days: 1)),
    ('9223372036854775807', const Duration(days: 1)),
    ('99999999999999999999999', const Duration(days: 1)),
  ]) {
    test('GivenARetryAfterHeader_WhenMapped_ThenTheWaitIsBounded: $raw', () {
      // Given
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/auth/resend-verification'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/api/auth/resend-verification'),
          statusCode: 429,
          headers: Headers.fromMap(<String, List<String>>{
            if (raw != null) 'retry-after': <String>[raw],
          }),
        ),
        type: DioExceptionType.badResponse,
      );

      // When
      final failure = failureFromDioException(error);

      // Then
      expect(failure.retryAfter, expected);
      expect(failure.pause, expected);
    });
  }
}

String _capitalized(String name) =>
    '${name[0].toUpperCase()}${name.substring(1)}';
