import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/auth_interceptor.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';

void main() {
  AuthToken? token;
  late Dio dio;
  late int unauthorizedCalls;

  setUp(() {
    token = null;
    unauthorizedCalls = 0;
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..interceptors.add(
        AuthInterceptor(
          sessionToken: () => token,
          onUnauthorized: () async => unauthorizedCalls++,
        ),
      );
  });

  test('GivenAToken_WhenRequestSent_ThenBearerHeaderIsAttached', () async {
    // Given
    token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));
    String? seenHeader;
    dio.httpClientAdapter = _CapturingAdapter((options) {
      seenHeader = options.headers['Authorization'] as String?;

      return 200;
    });

    // When
    await dio.get<dynamic>('/api/scopes');

    // Then
    expect(seenHeader, 'Bearer jwt');
  });

  test('GivenNoToken_WhenRequestSent_ThenNoBearerHeaderIsAttached', () async {
    // Given
    String? seenHeader;
    dio.httpClientAdapter = _CapturingAdapter((options) {
      seenHeader = options.headers['Authorization'] as String?;

      return 200;
    });

    // When
    await dio.post<dynamic>('/api/auth/login');

    // Then
    expect(seenHeader, isNull);
  });

  test('GivenExpiredToken_WhenRequestSent_ThenItIsNotAttached', () async {
    // Given
    token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2000));
    String? seenHeader;
    dio.httpClientAdapter = _CapturingAdapter((options) {
      seenHeader = options.headers['Authorization'] as String?;

      return 200;
    });

    // When
    await dio.get<dynamic>('/api/scopes');

    // Then
    expect(seenHeader, isNull);
  });

  test('GivenUnauthorizedResponse_WhenReceived_ThenSessionIsCleared', () async {
    // Given
    token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));
    dio.httpClientAdapter = _CapturingAdapter((_) => 401);

    // When
    await expectLater(
      dio.get<dynamic>('/api/scopes'),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(unauthorizedCalls, 1);
  });

  test('GivenForbiddenResponse_WhenReceived_ThenSessionIsLeftAlone', () async {
    // Given
    token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));
    dio.httpClientAdapter = _CapturingAdapter((_) => 403);

    // When
    await expectLater(
      dio.get<dynamic>('/api/scopes'),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(unauthorizedCalls, 0);
  });

  // AF-01a — a refused sign-in is made with no session, so there is no
  // session to end and nothing to say ended.
  test(
    'GivenNoSession_WhenUnauthorizedReceived_ThenNothingIsCleared',
    () async {
      // Given
      dio.httpClientAdapter = _CapturingAdapter(
        (_) => 401,
        body: '{"success":false,"errors":["Invalid credentials."]}',
      );

      // When
      await expectLater(
        dio.post<dynamic>('/api/auth/login'),
        throwsA(isA<DioException>()),
      );

      // Then
      expect(unauthorizedCalls, 0);
    },
  );

  // AF-09d — a mistyped password or code is answered 401 by the API, and is
  // the person's to correct, not a reason to sign them out.
  for (final message in <String>[
    'The current password is incorrect.',
    'The code or recovery code is missing, incorrect, or already used.',
  ]) {
    test(
      'GivenASession_WhenATypedCredentialIsRefused_ThenItSurvives: $message',
      () async {
        // Given
        token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));
        dio.httpClientAdapter = _CapturingAdapter(
          (_) => 401,
          body: '{"success":false,"errors":["$message"]}',
        );

        // When
        await expectLater(
          dio.post<dynamic>('/api/auth/2fa/disable'),
          throwsA(isA<DioException>()),
        );

        // Then
        expect(unauthorizedCalls, 0);
      },
    );
  }

  // FR-AU-16 and FR-AU-17 — changing your own address and starting a
  // two-factor setup ask for the password, and for the address a code too.
  // A mistyped one is answered 401 under a token that is still good.
  for (final (method, path) in <(String, String)>[
    ('PUT', '/api/persons/person-1'),
    ('POST', '/api/auth/2fa/enable'),
  ]) {
    for (final message in <String>[
      'The current password is incorrect.',
      'The code or recovery code is missing, incorrect, or already used.',
    ]) {
      test('GivenASession_WhenAReauthenticationIsRefused_ThenItSurvives: '
          '$method $path $message', () async {
        // Given
        token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));
        dio.httpClientAdapter = _CapturingAdapter(
          (_) => 401,
          body: '{"success":false,"errors":["$message"]}',
        );

        // When
        await expectLater(
          dio.request<dynamic>(path, options: Options(method: method)),
          throwsA(isA<DioException>()),
        );

        // Then
        expect(unauthorizedCalls, 0);
      });
    }
  }

  // AF-08h, AF-09a, AF-09d, AF-09f, AF-30e — every re-authentication under
  // a token now answers a wrong or missing password or code, and a paused
  // budget, with one 401 message. It is the person's to correct, wherever it
  // comes from.
  for (final (method, path) in <(String, String)>[
    ('POST', '/api/auth/2fa/enable'),
    ('POST', '/api/auth/2fa/confirm'),
    ('POST', '/api/auth/2fa/disable'),
    ('POST', '/api/auth/2fa/recovery-codes/regenerate'),
    ('PUT', '/api/persons/person-1'),
    ('POST', '/api/auth/erasure-request'),
  ]) {
    test('GivenASession_WhenTheUnifiedRefusalArrives_ThenItSurvives: '
        '$method $path', () async {
      // Given
      token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));
      dio.httpClientAdapter = _CapturingAdapter(
        (_) => 401,
        body:
            '{"success":false,"errors":'
            '["The password or code is incorrect."]}',
      );

      // When
      await expectLater(
        dio.request<dynamic>(path, options: Options(method: method)),
        throwsA(isA<DioException>()),
      );

      // Then
      expect(unauthorizedCalls, 0);
    });
  }

  // FR-AU-28 — a token revoked by a change to the sign-in details is a
  // refused session, not a refused credential, and ends it.
  test('GivenARevokedToken_WhenRefused_ThenTheSessionEnds', () async {
    // Given
    token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030));
    dio.httpClientAdapter = _CapturingAdapter(
      (_) => 401,
      body:
          '{"success":false,"errors":'
          '["This token has been revoked. Sign in again."]}',
    );

    // When
    await expectLater(
      dio.get<dynamic>('/api/auth/2fa'),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(unauthorizedCalls, 1);
  });

  // AF-07e — a session token past its expiry is not sent, and the 401 that
  // answers for it still ends the session.
  test('GivenAnExpiredSession_WhenUnauthorizedReceived_ThenItEnds', () async {
    // Given
    token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2000));
    dio.httpClientAdapter = _CapturingAdapter((_) => 401, body: '');

    // When
    await expectLater(
      dio.get<dynamic>('/api/scopes'),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(unauthorizedCalls, 1);
  });

  // A 401 answering a request of an earlier session is that session's
  // business: the one now on screen, perhaps somebody else's, is left alone.
  test(
    'GivenANewSession_WhenAnEarlierOnesRequestIsRefused_ThenItSurvives',
    () async {
      // Given
      token = AuthToken(value: 'earlier', expiresAt: DateTime.utc(2030));
      dio.httpClientAdapter = _CapturingAdapter((_) {
        token = AuthToken(value: 'current', expiresAt: DateTime.utc(2030));

        return 401;
      });

      // When
      await expectLater(
        dio.get<dynamic>('/api/scopes'),
        throwsA(isA<DioException>()),
      );

      // Then
      expect(unauthorizedCalls, 0);
    },
  );

  // Nor is a session that has already ended said to have ended again.
  test(
    'GivenAnEndedSession_WhenItsRequestIsRefused_ThenNothingIsCleared',
    () async {
      // Given
      token = AuthToken(value: 'earlier', expiresAt: DateTime.utc(2030));
      dio.httpClientAdapter = _CapturingAdapter((_) {
        token = null;

        return 401;
      });

      // When
      await expectLater(
        dio.get<dynamic>('/api/scopes'),
        throwsA(isA<DioException>()),
      );

      // Then
      expect(unauthorizedCalls, 0);
    },
  );
}

/// An adapter that answers locally and reports what it was asked for, so no
/// test ever reaches the network.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(
    this._respond, {
    this.body = '{"success":true,"errors":[],"data":null}',
  });

  final int Function(RequestOptions options) _respond;
  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    _respond(options),
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
