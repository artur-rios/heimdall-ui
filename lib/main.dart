import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:heimdall_api_client/export.dart';

import 'app/heimdall_app.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'core/storage/token_store.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/presentation/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
        tokenStoreProvider.overrideWithValue(
          const SecureTokenStore(FlutterSecureStorage()),
        ),
        authRepositoryProvider.overrideWith(
          (ref) => ApiAuthRepository(AuthClient(ref.watch(dioProvider))),
        ),
      ],
      child: const HeimdallApp(),
    ),
  );
}
