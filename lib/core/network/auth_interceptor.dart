import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'envelope.dart';

/// Attaches the bearer token to outgoing requests and reacts to a rejected one.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.sessionToken, required this.onUnauthorized});

  /// Marks a request made under a session, whether or not its token was still
  /// fresh enough to attach.
  static const String _underSessionKey = 'heimdall.underSession';

  /// The token of the session this client is acting for, or null when there
  /// is none.
  ///
  /// FR-AU-07: read from the session held in memory, never back from the
  /// store. The store is shared with whatever else runs on the device — on the
  /// web, every tab of the browser that shares its storage — so what it holds
  /// may by now be somebody else's token. The session is the identity this
  /// screen shows, and it is the one that acts.
  final AuthToken? Function() sessionToken;

  /// Called on a 401 so the session can be cleared and the user sent to
  /// sign-in. A 403 is left alone: the caller is who they claim to be and
  /// simply may not do this, which is the screen's problem, not the session's.
  final Future<void> Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = sessionToken();

    if (token != null) {
      options.extra[_underSessionKey] = true;

      if (!token.isExpired) {
        options.headers['Authorization'] = 'Bearer ${token.value}';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_endsTheSession(err)) {
      await onUnauthorized();
    }

    handler.next(err);
  }

  /// Whether a failure means the session token itself was refused.
  ///
  /// AF-07e is about a token rejected mid-session, and two kinds of 401 are
  /// not that: one answering a request made with no session at all (a refused
  /// sign-in or second factor, where there is no session to end), and one
  /// refusing a password or code typed into the request (AF-02a, AF-09d),
  /// which the person is meant to correct rather than be signed out over.
  static bool _endsTheSession(DioException err) {
    final response = err.response;

    return response?.statusCode == 401 &&
        err.requestOptions.extra[_underSessionKey] == true &&
        !rejectsSubmittedCredential(response?.data);
  }
}
