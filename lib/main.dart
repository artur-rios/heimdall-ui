import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heimdall_api_client/export.dart';

import 'app/heimdall_app.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'core/scope/scope_source.dart';
import 'core/scope/session_scope_source.dart';
import 'core/storage/token_store.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/data/google_sign_in_gateway_impl.dart';
import 'features/auth/presentation/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  runApp(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
        tokenStoreProvider.overrideWithValue(
          const SecureTokenStore(FlutterSecureStorage()),
        ),
        // The scope belongs to whichever application sent the user here; on the
        // web it is read from session storage on every use, so a caller may
        // change it between one attempt and the next.
        scopeSourceProvider.overrideWithValue(
          sessionScopeSource(fallback: config.scopeId),
        ),
        authRepositoryProvider.overrideWith(
          (ref) => ApiAuthRepository(AuthClient(ref.watch(dioProvider))),
        ),
        googleSignInGatewayProvider.overrideWithValue(
          PluginGoogleSignInGateway(
            GoogleSignIn.instance,
            config.googleClientId,
          ),
        ),
      ],
      child: const HeimdallApp(),
    ),
  );
}
