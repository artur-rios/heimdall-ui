import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/layout/breakpoints.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../scope_invitations/presentation/scope_invitations_card.dart';
import '../../scope_invitations/presentation/scope_invitations_controller.dart';
import 'dashboard_controller.dart';
import 'widgets/account_summary.dart';
import 'widgets/admin_dashboard.dart';
import 'widgets/greeting.dart';
import 'widgets/section_title.dart';

/// How a role is written wherever one is shown; lives in its own file so the
/// section widgets can use it without importing this screen.
export 'role_label.dart';

/// The screen behind `/`: a dashboard of what the signed-in person can reach.
///
/// Everybody sees their own account at a glance — the address, whether it is
/// verified, whether a second factor protects it. An administrator also sees
/// the figures of the scopes they administer, and each scope's own breakdown.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Read once the first frame is scheduled, so no controller is written to
    // during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Reads Home's data. A plain call — entering Home, coming back to it — may
  /// reuse a dashboard read in the last minute; [force], the explicit refresh,
  /// never does (#172).
  Future<void> _refresh({bool force = false}) async {
    final session = ref.read(sessionControllerProvider);

    if (session is! Authenticated) {
      return;
    }

    await Future.wait(<Future<void>>[
      ref.read(profileControllerProvider.notifier).load(),
      if (session.principal.administersAnything)
        ref.read(dashboardControllerProvider.notifier).load(force: force),
      if (session.principal.administersAnything)
        ref.read(scopeInvitationsControllerProvider.notifier).load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);

    if (session is! Authenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final principal = session.principal;
    final dashboard = principal.administersAnything
        ? ref.watch(dashboardControllerProvider)
        : null;
    final refreshing = switch (dashboard) {
      DashboardLoading() => true,
      DashboardLoaded(:final refreshing) => refreshing,
      _ => false,
    };

    return AppShell(
      currentRoute: '/',
      title: const Text('Home'),
      // Back from the System Admins listing, which may have changed a count.
      onReturn: _refresh,
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: refreshing ? null : () => _refresh(force: true),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _refresh(force: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(
            context.breakpoint == Breakpoint.compact ? 16 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Greeting(principal: principal),
                  const SizedBox(height: 24),
                  // UI-39: shown only while there is something to answer.
                  if (principal.administersAnything)
                    ScopeInvitationsCard(
                      onAccepted: () {
                        // The answer can arrive after Home was left.
                        if (!mounted) {
                          return;
                        }

                        unawaited(
                          ref
                              .read(dashboardControllerProvider.notifier)
                              .load(force: true),
                        );
                      },
                    ),
                  if (dashboard != null) ...<Widget>[
                    AdminDashboard(
                      state: dashboard,
                      isSystemAdmin: principal.isSystemAdmin,
                      onRetry: () => _refresh(force: true),
                    ),
                    const SizedBox(height: 32),
                  ],
                  const SectionTitle('Your account'),
                  const SizedBox(height: 12),
                  AccountSummary(
                    principal: principal,
                    viaGoogle: session.token.viaGoogle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
