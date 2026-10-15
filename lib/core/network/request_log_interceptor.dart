import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A debug-only request log that records what happened and nothing it was
/// given.
///
/// One line per request, once it has an outcome: the method, the path, the
/// status — or, when no response came, the kind of transport error — and how
/// long it took, as in `GET /api/scopes 200 (42 ms)`.
///
/// Headers, query strings, `extra`, bodies, and a [DioException]'s message and
/// response are never written: they carry the bearer token, recovery codes,
/// email addresses, and cookies, none of which belong in a console or a log a
/// developer shares.
class RequestLogInterceptor extends Interceptor {
  /// Writes each line to [log], which is `debugPrint` unless a test captures
  /// it.
  RequestLogInterceptor({void Function(String line)? log})
    : _log = log ?? debugPrint;

  final void Function(String line) _log;

  // Kept beside the request rather than in its `extra`, so the log adds
  // nothing to what is sent or seen by any other interceptor.
  final Expando<Stopwatch> _clocks = Expando<Stopwatch>('request clock');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _clocks[options] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _write(response.requestOptions, '${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;

    _write(err.requestOptions, status == null ? err.type.name : '$status');
    handler.next(err);
  }

  void _write(RequestOptions options, String outcome) {
    final clock = _clocks[options];
    final took = clock == null ? '' : ' (${clock.elapsedMilliseconds} ms)';

    // The path alone: the query string can carry an email address or a token.
    _log('${options.method} ${options.uri.path} $outcome$took');
  }
}
