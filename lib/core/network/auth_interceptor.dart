import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// Attaches the bearer token to outgoing requests and reacts to a rejected one.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenStore, required this.onUnauthorized});

  final TokenStore tokenStore;

  /// Called on a 401 so the session can be cleared and the user sent to
  /// sign-in. A 403 is left alone: the caller is who they claim to be and
  /// simply may not do this, which is the screen's problem, not the session's.
  final Future<void> Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStore.read();

    if (token != null && !token.isExpired) {
      options.headers['Authorization'] = 'Bearer ${token.value}';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await onUnauthorized();
    }

    handler.next(err);
  }
}
