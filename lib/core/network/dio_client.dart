import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';
import 'request_log_interceptor.dart';

/// Overridden at start-up with the configuration read from the environment.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

/// Builds the single [Dio] every generated client shares.
///
/// The default `validateStatus` is kept deliberately: a non-2xx must raise a
/// [DioException] so the interceptor sees a 401 and the repositories can map
/// the failure through `failureFromDioException`, which reads the API's own
/// `errors` array out of the error response's body.
Dio createDio({
  required AppConfig config,
  required AuthToken? Function() sessionToken,
  required Future<void> Function() onUnauthorized,
}) {
  final dio =
      Dio(
          BaseOptions(
            baseUrl: config.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            contentType: Headers.jsonContentType,
          ),
        )
        ..interceptors.add(
          AuthInterceptor(
            sessionToken: sessionToken,
            onUnauthorized: onUnauthorized,
          ),
        );

  if (kDebugMode) {
    // Method, path, status and duration only. Dio's own LogInterceptor also
    // prints headers — the bearer token among them — query strings, `extra`,
    // and the error's text; none of that belongs in a console log.
    dio.interceptors.add(RequestLogInterceptor());
  }

  return dio;
}

/// The configured HTTP client, shared by every feature's data layer.
final Provider<Dio> dioProvider = Provider<Dio>(
  (ref) => createDio(
    config: ref.watch(appConfigProvider),
    // FR-AU-07: the session's own token, not the store's — see
    // [AuthInterceptor.sessionToken].
    sessionToken: () => switch (ref.read(sessionControllerProvider)) {
      Authenticated(:final token) => token,
      _ => null,
    },
    // AF-07e: the token was rejected mid-session, which is not the same as
    // signing out — the user is told the session ended.
    onUnauthorized: () =>
        ref.read(sessionControllerProvider.notifier).signOut(expired: true),
  ),
);
