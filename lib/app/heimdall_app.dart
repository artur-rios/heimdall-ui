import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/session.dart';
import '../features/auth/presentation/session_controller.dart';
import '../shared/widgets/page_title.dart';
import 'app_version.dart';
import 'router.dart';
import 'session_scoped_state.dart';
import 'theme.dart';
import 'theme_mode_controller.dart';

/// The application root: theme, router, and the version footer under both.
class HeimdallApp extends ConsumerWidget {
  const HeimdallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final restoring = ref.watch(sessionControllerProvider) is SessionRestoring;

    // A session that ends takes everything it was shown with it, so the next
    // person to sign in on this device starts from nothing.
    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (previous is Authenticated && next is! Authenticated) {
        for (final provider in sessionScopedProviders) {
          ref.invalidate(provider);
        }
      }
    });

    return MaterialApp.router(
      // The screen on top names the tab; the application's own title would
      // put the bare name back whenever the application rebuilds.
      onGenerateTitle: (_) => PageTitle.currentLabel,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      // AF-07c: while the stored token is being read the guard decides nothing,
      // so this covers whatever the router built underneath rather than
      // replacing it — the requested URL survives a slow read intact.
      builder: (context, child) => Column(
        children: <Widget>[
          Expanded(
            // The footer below takes the bottom inset, so the screen above it
            // must not leave room for it a second time.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: restoring
                  ? const _RestoringScreen()
                  : child ?? const SizedBox(),
            ),
          ),
          // Every screen, signed in or not, says which release is running.
          const AppVersionFooter(),
        ],
      ),
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
