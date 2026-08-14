import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/export.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/data/auth_repository_impl.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';

void main() {
  late Dio dio;
  late ApiAuthRepository repository;

  ApiAuthRepository repositoryAnswering(_Answer answer) {
    dio.httpClientAdapter = _StubAdapter(answer);

    return ApiAuthRepository(AuthClient(dio));
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  });

  test('GivenTokenResponse_WhenLoggingIn_ThenLoggedInIsReturned', () async {
    // Given
    repository = repositoryAnswering(
      _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'token': 'jwt',
            'expiresAt': '2030-01-01T00:00:00Z',
            'requiresTwoFactor': false,
          },
        },
      ),
    );

    // When
    final result = await repository.login(email: 'a@b.c', password: 'secret');

    // Then
    expect(result.valueOrNull, isA<LoggedIn>());
    expect((result.valueOrNull! as LoggedIn).token.value, 'jwt');
  });

  // AF-01c — the API answers with a challenge instead of a token.
  test(
    'GivenTwoFactorResponse_WhenLoggingIn_ThenTwoFactorRequiredIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': true,
            'errors': <String>[],
            'data': <String, dynamic>{
              'requiresTwoFactor': true,
              'challengeToken': 'challenge',
              'availableMethods': <String>['Totp', 'Email'],
            },
          },
        ),
      );

      // When
      final result = await repository.login(email: 'a@b.c', password: 'secret');

      // Then
      final outcome = result.valueOrNull;
      expect(outcome, isA<TwoFactorRequired>());
      expect((outcome! as TwoFactorRequired).challengeToken, 'challenge');
      expect((outcome as TwoFactorRequired).availableMethods, <String>[
        'Totp',
        'Email',
      ]);
    },
  );

  // AF-01a — an unsuccessful envelope carries the reason in `errors`.
  test(
    'GivenRejectedEnvelope_WhenLoggingIn_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        _Answer(
          status: 200,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Invalid email or password.'],
            'data': null,
          },
        ),
      );

      // When
      final result = await repository.login(email: 'a@b.c', password: 'wrong');

      // Then
      expect(result.failureOrNull?.errors, <String>[
        'Invalid email or password.',
      ]);
    },
  );

  // AF-01a — the API answers 401 for every rejection, body and all.
  test(
    'GivenUnauthorizedStatus_WhenLoggingIn_ThenApiErrorsAreReturned',
    () async {
      // Given
      repository = repositoryAnswering(
        _Answer(
          status: 401,
          body: <String, dynamic>{
            'success': false,
            'errors': <String>['Invalid credentials.'],
          },
        ),
      );

      // When
      final result = await repository.login(email: 'a@b.c', password: 'wrong');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.unauthorized);
      expect(result.failureOrNull?.errors, <String>['Invalid credentials.']);
    },
  );

  // AF-01d — the API could not be reached at all.
  test(
    'GivenTransportFailure_WhenLoggingIn_ThenNetworkFailureIsReturned',
    () async {
      // Given
      repository = repositoryAnswering(const _Answer(status: 0));

      // When
      final result = await repository.login(email: 'a@b.c', password: 'secret');

      // Then
      expect(result.failureOrNull?.kind, FailureKind.network);
    },
  );

  // A successful envelope that carries neither a token nor a challenge.
  test('GivenIncompleteEnvelope_WhenLoggingIn_ThenFailureIsReturned', () async {
    // Given
    repository = repositoryAnswering(
      _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{'requiresTwoFactor': false},
        },
      ),
    );

    // When
    final result = await repository.login(email: 'a@b.c', password: 'secret');

    // Then
    expect(result.failureOrNull, isNotNull);
  });
}

/// What the stub answers with. A [status] of zero stands for a connection that
/// never got as far as a response.
class _Answer {
  const _Answer({required this.status, this.body});

  final int status;
  final Map<String, dynamic>? body;
}

/// Answers from memory, so no test reaches the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._answer);

  final _Answer _answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_answer.status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No route to host',
      );
    }

    return ResponseBody.fromString(
      jsonEncode(_answer.body),
      _answer.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
