import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/session.dart';
import '../features/auth/presentation/session_controller.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_mode_controller.dart';

/// The application root: theme, router, and nothing else.
class HeimdallApp extends ConsumerWidget {
  const HeimdallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final restoring = ref.watch(sessionControllerProvider) is SessionRestoring;

    return MaterialApp.router(
      title: 'Heimdall',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      // AF-07c: while the stored token is being read the guard decides nothing,
      // so this covers whatever the router built underneath rather than
      // replacing it — the requested URL survives a slow read intact.
      builder: (context, child) =>
          restoring ? const _RestoringScreen() : child ?? const SizedBox(),
    );
  }
}

/// What a caller sees while the session is being restored: a wait, not a
/// sign-in screen they never asked for.
class _RestoringScreen extends StatelessWidget {
  const _RestoringScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
