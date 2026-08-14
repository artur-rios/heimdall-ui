import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme_mode_controller.dart';
import '../../../shared/layout/adaptive_scaffold.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../auth/presentation/verification_banner.dart';
import 'destinations.dart';

/// The screen behind `/`, and the shell every administrative screen will be
/// hosted in once the feature use cases add their routes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session is! Authenticated) {
      // The guard is already redirecting; this is what the frame in between
      // shows rather than a half-built shell.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final principal = session.principal;
    final destinations = destinationsFor(principal);

    return AdaptiveScaffold(
      destinations: destinations,
      selectedIndex: 0,
      onDestinationSelected: (index) => context.go(destinations[index].route),
      title: const Text('Heimdall'),
      actions: <Widget>[
        const _ThemeModeAction(),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () =>
              ref.read(sessionControllerProvider.notifier).signOut(),
        ),
      ],
      body: Column(
        children: <Widget>[
          // AF-05e: renders nothing when the address is verified or the prompt
          // was dismissed, so it sits here unconditionally.
          const VerificationBanner(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Signed in as ${principal.email}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_roleLabel(principal.role)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(Role role) => switch (role) {
    Role.systemAdmin => 'System Admin',
    Role.scopeAdmin => 'Scope Admin',
    Role.user => 'User',
  };
}

/// Cycles system → light → dark, and shows which is active.
class _ThemeModeAction extends ConsumerWidget {
  const _ThemeModeAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

    return IconButton(
      tooltip: switch (mode) {
        ThemeMode.system => 'Theme: follow the system',
        ThemeMode.light => 'Theme: light',
        ThemeMode.dark => 'Theme: dark',
      },
      icon: Icon(switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      }),
      onPressed: () =>
          ref.read(themeModeControllerProvider.notifier).setMode(switch (mode) {
            ThemeMode.system => ThemeMode.light,
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => ThemeMode.system,
          }),
    );
  }
}
