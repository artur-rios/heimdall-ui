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
}

/// An adapter that answers locally and reports what it was asked for, so no
/// test ever reaches the network.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this._respond);

  final int Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"success":true,"errors":[],"data":null}',
    _respond(options),
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
