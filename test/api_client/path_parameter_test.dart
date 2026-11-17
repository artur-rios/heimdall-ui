import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/api.dart';

/// Records the request a client would send, and sends nothing.
class _Recorder extends Interceptor {
  RequestOptions? sent;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    sent = options;
    handler.reject(DioException(requestOptions: options, error: 'recorded'));
  }
}

void main() {
  const guid = '6f1d3a00-0000-0000-0000-000000000001';
  late _Recorder recorder;
  late GoogleUserClient client;

  setUp(() {
    recorder = _Recorder();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
      ..interceptors.add(recorder);
    client = GoogleUserClient(dio);
  });

  // A path parameter is one segment, whatever it holds: an id that decodes to
  // `../../persons/<id>?x=` must not reach another endpoint.
  test('GivenATraversalId_WhenAClientCalls_ThenItStaysOneSegment', () async {
    // Given
    const scopeId = '../../persons/$guid?x=';

    // When
    await expectLater(
      client.googleUserHardDelete(scopeId: scopeId, id: guid),
      throwsA(isA<DioException>()),
    );

    // Then
    final uri = recorder.sent!.uri;
    expect(
      uri.path,
      '/api/scopes/..%2F..%2Fpersons%2F$guid%3Fx%3D/google-users/$guid/hard',
    );
    expect(uri.query, isEmpty);
  });

  test('GivenAPublicId_WhenAClientCalls_ThenThePathIsUnchanged', () async {
    // Given / When
    await expectLater(
      client.googleUserHardDelete(scopeId: guid, id: guid),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(
      recorder.sent!.uri.toString(),
      'https://api.example.invalid/api/scopes/$guid/google-users/$guid/hard',
    );
  });

  // `.` and `..` survive encoding unchanged, and the URI would then drop or
  // climb a segment; an empty one would leave a gap. None is sent.
  for (final id in <String>['..', '.', '']) {
    test('GivenADotOrEmptyId_WhenAClientCalls_ThenNothingIsSent "$id"', () {
      // Given / When
      Future<void> call() => client.googleUserHardDelete(scopeId: id, id: guid);

      // Then
      expect(call, throwsArgumentError);
      expect(recorder.sent, isNull);
    });
  }

  // A call that passes `options` takes the direct Dio fallback swagger_parser
  // writes beside the retrofit method, which builds its own path.
  test(
    'GivenATraversalId_WhenACallPassesOptions_ThenItStaysOneSegment',
    () async {
      // Given
      const scopeId = '../../persons/$guid?x=';

      // When
      await expectLater(
        client.googleUserHardDelete(
          scopeId: scopeId,
          id: guid,
          options: Options(),
        ),
        throwsA(isA<DioException>()),
      );

      // Then
      final uri = recorder.sent!.uri;
      expect(
        uri.path,
        '/api/scopes/..%2F..%2Fpersons%2F$guid%3Fx%3D/google-users/$guid/hard',
      );
      expect(uri.query, isEmpty);
    },
  );

  test('GivenADotId_WhenACallPassesOptions_ThenNothingIsSent', () {
    // Given / When
    Future<void> call() => client.googleUserHardDelete(
      scopeId: '..',
      id: guid,
      options: Options(),
    );

    // Then
    expect(call, throwsArgumentError);
    expect(recorder.sent, isNull);
  });

  // Every generated path, not just the one above: a regeneration that skipped
  // the encoding step would put the raw parameter back.
  test('GivenTheGeneratedClients_WhenTheirPathsAreRead_ThenAllAreEncoded', () {
    // Given
    final sources = Directory('packages/heimdall_api_client/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('_client.dart') ||
              file.path.endsWith('_client.g.dart'),
        );
    final literal = RegExp(r"'(/api[^']*)'");
    final parameter = RegExp(r'\$\{([^}]*)\}');
    final fallback = RegExp(r'_transport\.request<[^>]*>\(\s*("/api[^,]*)');
    final stringified = RegExp(r'\b\w+\.toString\(\)');

    // When
    final raw = <String>[];
    var encoded = 0;
    for (final file in sources) {
      final source = file.readAsStringSync();
      for (final path in literal.allMatches(source)) {
        for (final match in parameter.allMatches(path.group(1)!)) {
          if (match.group(1)!.startsWith('_pathSegment(')) {
            encoded++;
          } else {
            raw.add('${file.path}: ${path.group(1)}');
          }
        }
      }
      for (final path in fallback.allMatches(source)) {
        if (stringified.hasMatch(path.group(1)!)) {
          raw.add('${file.path}: ${path.group(1)}');
        } else if (path.group(1)!.contains('_pathSegment(')) {
          encoded++;
        }
      }
    }

    // Then
    expect(raw, isEmpty);
    expect(encoded, greaterThan(0));
  });
}
