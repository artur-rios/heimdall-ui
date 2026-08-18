import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme_mode_controller.dart';
import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/verification_banner.dart';
import '../../features/home/presentation/destinations.dart';
import 'adaptive_scaffold.dart';

/// The frame every signed-in screen sits in: the navigation for the role, the
/// theme control, sign-out, and the unverified-address prompt.
///
/// Screens hand it a [body] and a [currentRoute] and think about nothing else,
/// which is what keeps one shell decision in one place rather than one per
/// screen.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.currentRoute,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.floatingActionButton,
    super.key,
  });

  /// The destination route this screen belongs to, which decides what the
  /// navigation shows as selected. A screen below a destination — a detail
  /// under a listing — passes the destination's own route.
  final String currentRoute;
  final Widget title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session is! Authenticated) {
      // The guard is already redirecting; this is what the frame in between
      // shows rather than a half-built shell.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final destinations = destinationsFor(session.principal);
    final selected = destinations.indexWhere(
      (destination) => destination.route == currentRoute,
    );

    return AdaptiveScaffold(
      destinations: destinations,
      // A screen that is not itself a destination still has to select
      // something; the first entry is what the navigation highlights.
      selectedIndex: selected < 0 ? 0 : selected,
      onDestinationSelected: (index) => context.go(destinations[index].route),
      title: title,
      floatingActionButton: floatingActionButton,
      actions: <Widget>[
        ...actions,
        const ThemeModeAction(),
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
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Cycles system → light → dark, and shows which is active.
class ThemeModeAction extends ConsumerWidget {
  const ThemeModeAction({super.key});

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
