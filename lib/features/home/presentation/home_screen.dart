import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';

/// The screen behind `/`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session is! Authenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final principal = session.principal;

    return AppShell(
      currentRoute: '/',
      title: const Text('Heimdall'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                principal.displayName.isEmpty
                    ? 'Signed in'
                    : 'Signed in as ${principal.displayName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(roleLabel(principal.role)),
              const SizedBox(height: 24),
              // A User is offered one destination, which the shell does not
              // render as navigation — so without this their profile and
              // security settings (UI-08, UI-09) are unreachable from here.
              FilledButton.tonalIcon(
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.person_outline),
                label: const Text('Your profile and security'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a role is written wherever one is shown.
String roleLabel(Role role) => switch (role) {
  Role.systemAdmin => 'System Admin',
  Role.scopeAdmin => 'Scope Admin',
  Role.user => 'User',
};
