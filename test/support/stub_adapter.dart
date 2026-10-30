import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What a [StubAdapter] answers: a status and a JSON [body].
///
/// A [status] of 0 is no answer at all, a failed connection. A null [body] is
/// an empty response, as a 204 has.
class StubAnswer {
  const StubAnswer({required this.status, this.body});

  final int status;
  final Map<String, dynamic>? body;
}

/// Answers every request with [answer] from memory, so no test reaches the
/// network, and records what it was sent so a test can assert which endpoint,
/// filters and fields travelled.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.answer);

  final StubAnswer answer;

  /// The full address of each request, in order.
  final List<Uri> uris = <Uri>[];

  /// The path each request addressed, as given to the client.
  final List<String> paths = <String>[];

  final List<String> methods = <String>[];

  /// The query parameters of each request, before they are encoded.
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  /// The body each request carried, round-tripped through JSON; null when it
  /// carried none.
  final List<Object?> bodies = <Object?>[];

  /// The JSON object bodies read off the request stream, which is what
  /// actually travelled. Requests without one add nothing.
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uris.add(options.uri);
    paths.add(options.path);
    methods.add(options.method);
    queries.add(options.queryParameters);
    bodies.add(
      options.data == null ? null : jsonDecode(jsonEncode(options.data)),
    );

    if (requestStream != null) {
      final bytes = <int>[];

      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }

      if (bytes.isNotEmpty) {
        if (jsonDecode(utf8.decode(bytes)) case final Map<String, dynamic> b) {
          requests.add(b);
        }
      }
    }

    if (answer.status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No route to host',
      );
    }

    final body = answer.body;

    return body == null
        ? ResponseBody.fromString('', answer.status)
        : ResponseBody.fromString(
            jsonEncode(body),
            answer.status,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
  }

  @override
  void close({bool force = false}) {}
}
