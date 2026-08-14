import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

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
  required TokenStore tokenStore,
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
            tokenStore: tokenStore,
            onUnauthorized: onUnauthorized,
          ),
        );

  if (kDebugMode) {
    // Bodies are omitted on purpose: they carry tokens, recovery codes, and
    // email addresses, none of which belong in a console log.
    dio.interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false),
    );
  }

  return dio;
}

/// The configured HTTP client, shared by every feature's data layer.
final Provider<Dio> dioProvider = Provider<Dio>(
  (ref) => createDio(
    config: ref.watch(appConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    // AF-07e: the token was rejected mid-session, which is not the same as
    // signing out — the user is told the session ended.
    onUnauthorized: () =>
        ref.read(sessionControllerProvider.notifier).signOut(expired: true),
  ),
);
