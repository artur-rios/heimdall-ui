import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/auth_interceptor.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';

void main() {
  late InMemoryTokenStore store;
  late Dio dio;
  late int unauthorizedCalls;

  setUp(() {
    store = InMemoryTokenStore();
    unauthorizedCalls = 0;
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..interceptors.add(
        AuthInterceptor(
          tokenStore: store,
          onUnauthorized: () async => unauthorizedCalls++,
        ),
      );
  });

  test('GivenStoredToken_WhenRequestSent_ThenBearerHeaderIsAttached', () async {
    // Given
    await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)));
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
    await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2000)));
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
    await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)));
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
    await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)));
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
        await store.write(
          AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
        );
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

  // AF-07e — a stored token past its expiry is not sent, and the 401 that
  // answers for it still ends the session.
  test('GivenAnExpiredSession_WhenUnauthorizedReceived_ThenItEnds', () async {
    // Given
    await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2000)));
    dio.httpClientAdapter = _CapturingAdapter((_) => 401, body: '');

    // When
    await expectLater(
      dio.get<dynamic>('/api/scopes'),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(unauthorizedCalls, 1);
  });
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
