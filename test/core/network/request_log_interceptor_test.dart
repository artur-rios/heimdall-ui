import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/auth_interceptor.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/network/request_log_interceptor.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';

void main() {
  late AuthToken token;
  late List<String> lines;
  late Dio dio;

  setUp(() {
    token = AuthToken(value: 'jwt-secret', expiresAt: DateTime.utc(2030));
    lines = <String>[];
    // The order the application uses: the bearer is attached first, so the
    // logger sees every request exactly as it leaves.
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..interceptors.addAll(<Interceptor>[
        AuthInterceptor(sessionToken: () => token, onUnauthorized: () async {}),
        RequestLogInterceptor(log: lines.add),
      ]);
  });

  test(
    'GivenASuccessfulRequest_WhenLogged_ThenItNamesMethodPathAndStatus',
    () async {
      // Given
      dio.httpClientAdapter = _Adapter((_) => 200);

      // When
      await dio.get<dynamic>('/api/scopes');

      // Then
      expect(lines, hasLength(1));
      expect(
        lines.single,
        matches(RegExp(r'^GET /api/scopes 200 \(\d+ ms\)$')),
      );
    },
  );

  test(
    'GivenABearerAQueryAndExtra_WhenLogged_ThenNoneOfThemIsPrinted',
    () async {
      // Given
      dio.httpClientAdapter = _Adapter((_) => 200);

      // When
      await dio.get<dynamic>(
        '/api/persons',
        queryParameters: <String, dynamic>{'Email': 'ada@example.com'},
        options: Options(
          headers: <String, dynamic>{'X-Custom': 'header-value'},
          extra: <String, dynamic>{'note': 'extra-value'},
        ),
      );

      // Then
      final output = lines.join('\n');
      expect(output, contains('GET /api/persons 200'));
      expect(output, isNot(contains('Bearer')));
      expect(output, isNot(contains('jwt-secret')));
      expect(output, isNot(contains('Authorization')));
      expect(output, isNot(contains('header-value')));
      expect(output, isNot(contains('ada@example.com')));
      expect(output, isNot(contains('Email')));
      expect(output, isNot(contains('extra-value')));
    },
  );

  test('GivenAnErrorResponse_WhenLogged_ThenOnlyItsStatusIsPrinted', () async {
    // Given
    dio.httpClientAdapter = _Adapter(
      (_) => 404,
      body: '{"success":false,"errors":["body-secret"]}',
      headers: <String, List<String>>{
        'set-cookie': <String>['session=cookie-secret'],
      },
    );

    // When
    await expectLater(
      dio.post<dynamic>('/api/auth/login', data: <String, dynamic>{}),
      throwsA(isA<DioException>()),
    );

    // Then
    final output = lines.join('\n');
    expect(lines, hasLength(1));
    expect(output, matches(RegExp(r'^POST /api/auth/login 404 \(\d+ ms\)$')));
    expect(output, isNot(contains('body-secret')));
    expect(output, isNot(contains('cookie-secret')));
    expect(output, isNot(contains('Bearer')));
  });

  test(
    'GivenATransportFailure_WhenLogged_ThenOnlyTheErrorTypeIsPrinted',
    () async {
      // Given
      dio.httpClientAdapter = _Adapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'reason-secret',
        ),
      );

      // When
      await expectLater(
        dio.get<dynamic>(
          '/api/health',
          queryParameters: <String, dynamic>{'token': 'query-secret'},
        ),
        throwsA(isA<DioException>()),
      );

      // Then
      final output = lines.join('\n');
      expect(lines, hasLength(1));
      expect(
        output,
        matches(RegExp(r'^GET /api/health connectionError \(\d+ ms\)$')),
      );
      expect(output, isNot(contains('reason-secret')));
      expect(output, isNot(contains('query-secret')));
      expect(output, isNot(contains('Bearer')));
    },
  );

  test(
    'GivenADebugBuild_WhenTheClientIsBuilt_ThenItLogsThroughTheRedactingLogger',
    () {
      // When
      final built = createDio(
        config: const AppConfig(apiBaseUrl: 'https://example.invalid'),
        sessionToken: () => token,
        onUnauthorized: () async {},
      );

      // Then
      expect(built.interceptors.whereType<LogInterceptor>(), isEmpty);
      expect(
        built.interceptors.whereType<RequestLogInterceptor>(),
        hasLength(1),
      );
    },
  );
}

/// An adapter that answers locally, so no test ever reaches the network.
class _Adapter implements HttpClientAdapter {
  _Adapter(
    this._respond, {
    this.body = '{"success":true,"errors":[],"data":null}',
    this.headers = const <String, List<String>>{},
  });

  final int Function(RequestOptions options) _respond;
  final String body;
  final Map<String, List<String>> headers;

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
      ...headers,
    },
  );
}
