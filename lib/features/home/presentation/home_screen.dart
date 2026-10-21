import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/layout/breakpoints.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../scope_invitations/presentation/scope_invitations_card.dart';
import '../../scope_invitations/presentation/scope_invitations_controller.dart';
import '../domain/dashboard.dart';
import 'dashboard_controller.dart';

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
                  _Greeting(principal: principal),
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
                    _AdminDashboard(
                      state: dashboard,
                      isSystemAdmin: principal.isSystemAdmin,
                      onRetry: () => _refresh(force: true),
                    ),
                    const SizedBox(height: 32),
                  ],
                  const _SectionTitle('Your account'),
                  const SizedBox(height: 12),
                  _AccountSummary(
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

/// How a role is written wherever one is shown.
String roleLabel(Role role) => switch (role) {
  Role.systemAdmin => 'System Admin',
  Role.scopeAdmin => 'Scope Admin',
  Role.user => 'User',
};

class _Greeting extends StatelessWidget {
  const _Greeting({required this.principal});

  final Principal principal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = principal.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Chip(
              avatar: const Icon(Icons.badge_outlined, size: 18),
              label: Text(roleLabel(principal.role)),
              visualDensity: VisualDensity.compact,
            ),
            Text(
              switch (principal.role) {
                Role.systemAdmin => 'You administer every scope in Heimdall.',
                Role.scopeAdmin => 'You administer the scopes you own.',
                Role.user => 'Manage your profile and how you sign in.',
              },
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?trailing,
    ],
  );
}

/// The figures, then each scope's breakdown.
class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({
    required this.state,
    required this.isSystemAdmin,
    required this.onRetry,
  });

  final DashboardState state;
  final bool isSystemAdmin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => switch (state) {
    DashboardLoading() => const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle('Overview'),
        SizedBox(height: 12),
        _StatGrid(
          children: <Widget>[
            _StatTile.loading(label: 'Scopes', icon: Icons.domain_outlined),
            _StatTile.loading(label: 'Persons', icon: Icons.people_outline),
            _StatTile.loading(label: 'Applications', icon: Icons.apps_outlined),
            _StatTile.loading(label: 'Permissions', icon: Icons.key_outlined),
          ],
        ),
      ],
    ),
    DashboardFailed(:final failure) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionTitle('Overview'),
        const SizedBox(height: 12),
        CollectionFailed(failure: failure, onRetry: onRetry),
      ],
    ),
    DashboardLoaded(:final stats) => _LoadedDashboard(
      stats: stats,
      isSystemAdmin: isSystemAdmin,
    ),
  };
}

class _LoadedDashboard extends StatelessWidget {
  const _LoadedDashboard({required this.stats, required this.isSystemAdmin});

  final DashboardStats stats;
  final bool isSystemAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopeCount = stats.scopes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          'Overview',
          trailing: isSystemAdmin
              ? FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => context.go('/scopes/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New scope'),
                )
              : null,
        ),
        if (stats.isPartial) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            'Persons, applications, permissions and Google users are counted '
            'across the first $scopeCount of your ${stats.activeScopes} '
            'scopes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _StatGrid(
          children: <Widget>[
            _StatTile(
              label: 'Scopes',
              icon: Icons.domain_outlined,
              value: _figure(stats.activeScopes),
              caption: switch (stats.deletedScopes) {
                null => 'Active',
                0 => 'Active, none deleted',
                final deleted => 'Active, $deleted deleted',
              },
              onTap: () => context.go('/scopes'),
            ),
            _StatTile(
              label: 'Persons',
              icon: Icons.people_outline,
              value: _figure(stats.persons),
              tooltip: stats.persons == null ? 'Could not be read' : null,
              caption: 'Users in your scopes',
            ),
            _StatTile(
              label: 'Applications',
              icon: Icons.apps_outlined,
              value: _figure(stats.applications),
              tooltip: stats.applications == null ? 'Could not be read' : null,
              caption: 'Registered in your scopes',
            ),
            _StatTile(
              label: 'Permissions',
              icon: Icons.key_outlined,
              value: _figure(stats.permissions),
              tooltip: stats.permissions == null ? 'Could not be read' : null,
              caption: 'Defined in your scopes',
            ),
            _StatTile(
              label: 'Google users',
              icon: Icons.account_circle_outlined,
              value: _figure(stats.googleUsers),
              tooltip: stats.googleUsers == null ? 'Could not be read' : null,
              caption:
                  'Sign-In on in ${stats.googleSignInScopes} of '
                  '$scopeCount ${scopeCount == 1 ? 'scope' : 'scopes'}',
            ),
            if (isSystemAdmin)
              _StatTile(
                label: 'System Admins',
                icon: Icons.admin_panel_settings_outlined,
                value: _figure(stats.systemAdmins),
                tooltip: stats.systemAdmins == null
                    ? 'Could not be read'
                    : null,
                caption: 'Full access to every scope',
                onTap: () => context.go('/system-admins'),
              ),
            _ApiStatusTile(reachable: stats.apiReachable),
          ],
        ),
        const SizedBox(height: 32),
        _SectionTitle(
          'Scopes',
          trailing: TextButton(
            onPressed: () => context.go('/scopes'),
            child: const Text('View all'),
          ),
        ),
        const SizedBox(height: 12),
        if (stats.scopes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                isSystemAdmin
                    ? 'There are no scopes yet. Create the first one to start '
                          'adding persons, applications and permissions.'
                    : 'You do not own any scopes yet. A System Admin can make '
                          'you an owner of one.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          _ScopeBreakdown(summaries: stats.scopes),
      ],
    );
  }
}

/// Lays the tiles out in as many columns as the width allows, never letting a
/// tile shrink below [minTileWidth].
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children, this.minTileWidth = 150});

  final List<Widget> children;
  final double minTileWidth;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fit = ((constraints.maxWidth + _gap) / (minTileWidth + _gap))
          .floor();
      final columns = fit.clamp(1, 3);
      final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;

      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: <Widget>[
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// How a count reads on a tile: the number, or a dash when it could not be
/// read.
String _figure(int? value) => value == null ? '—' : '$value';

/// One figure: what it counts, the number, and a line about it.
///
/// Laid out beside its icon when there is room, and under it on a phone,
/// where two tiles share a row.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.caption,
    this.onTap,
    this.tooltip,
    this.iconBackground,
    this.iconForeground,
    this.valueColor,
  }) : loading = false;

  const _StatTile.loading({required this.label, required this.icon})
    : value = '',
      caption = '',
      onTap = null,
      tooltip = null,
      iconBackground = null,
      iconForeground = null,
      valueColor = null,
      loading = true;

  final String label;
  final IconData icon;
  final String value;
  final String caption;
  final VoidCallback? onTap;

  /// Said on hover, when the figure needs explaining — one that could not be
  /// read, say.
  final String? tooltip;
  final Color? iconBackground;
  final Color? iconForeground;
  final Color? valueColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget figure = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: valueColor,
      ),
    );

    if (tooltip case final message?) {
      figure = Tooltip(message: message, child: figure);
    }

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: LinearProgressIndicator(),
          )
        else
          figure,
        if (caption.isNotEmpty)
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    final iconBox = _TileIcon(
      icon: icon,
      background: iconBackground,
      foreground: iconForeground,
    );
    final chevron = onTap == null
        ? null
        : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 200
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[iconBox, const Spacer(), ?chevron],
                      ),
                      const SizedBox(height: 12),
                      text,
                    ],
                  )
                : Row(
                    children: <Widget>[
                      iconBox,
                      const SizedBox(width: 16),
                      Expanded(child: text),
                      ?chevron,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, this.background, this.foreground});

  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: foreground ?? scheme.onPrimaryContainer),
    );
  }
}

/// Whether the API answered its liveness check, and the way to the full
/// health report.
class _ApiStatusTile extends StatelessWidget {
  const _ApiStatusTile({required this.reachable});

  final bool? reachable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final up = reachable ?? false;

    return _StatTile(
      label: 'API',
      icon: up ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
      value: up ? 'Online' : 'Unreachable',
      caption: 'Open the health report',
      iconBackground: up ? scheme.tertiaryContainer : scheme.errorContainer,
      iconForeground: up ? scheme.onTertiaryContainer : scheme.onErrorContainer,
      valueColor: up ? null : scheme.error,
      onTap: () => context.go('/health'),
    );
  }
}

/// Each summarised scope, with what it holds, one tap from its detail.
class _ScopeBreakdown extends StatelessWidget {
  const _ScopeBreakdown({required this.summaries});

  final List<ScopeSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (final (index, summary) in summaries.indexed) ...<Widget>[
            if (index > 0) const Divider(height: 1),
            InkWell(
              onTap: () => context.go('/scopes/${summary.scope.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            summary.scope.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (summary.scope.description.isNotEmpty)
                            Text(
                              summary.scope.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _Count(
                                icon: Icons.people_outline,
                                value: summary.persons,
                                singular: 'person',
                                plural: 'persons',
                              ),
                              _Count(
                                icon: Icons.apps_outlined,
                                value: summary.applications,
                                singular: 'application',
                                plural: 'applications',
                              ),
                              _Count(
                                icon: Icons.key_outlined,
                                value: summary.permissions,
                                singular: 'permission',
                                plural: 'permissions',
                              ),
                              _Count(
                                icon: Icons.account_circle_outlined,
                                value: summary.googleUsers,
                                singular: 'Google user',
                                plural: 'Google users',
                              ),
                              if (summary.scope.googleSignInEnabled)
                                const _Badge(
                                  icon: Icons.login,
                                  label: 'Google Sign-In on',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.icon,
    required this.value,
    required this.singular,
    required this.plural,
  });

  final IconData icon;
  final int? value;
  final String singular;
  final String plural;

  @override
  Widget build(BuildContext context) => _Badge(
    icon: icon,
    label: switch (value) {
      null => '— $plural',
      1 => '1 $singular',
      final count => '$count $plural',
    },
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// The signed-in person's own account: who they are, how well it is
/// protected, and the way to change either.
///
/// A Google session's account is its Google User record (#133): the name and
/// address Google reported, in place of the second factor, which a Google User
/// may never configure.
class _AccountSummary extends ConsumerWidget {
  const _AccountSummary({required this.principal, required this.viaGoogle});

  final Principal principal;
  final bool viaGoogle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final (:email, :emailVerified) = switch (profile) {
      ProfileLoaded(:final person) => (
        email: person.email,
        emailVerified: person.emailVerified,
      ),
      GoogleProfileLoaded(:final user) => (
        email: user.email,
        emailVerified: user.emailVerified,
      ),
      _ => (email: null, emailVerified: null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatGrid(
          minTileWidth: 260,
          children: <Widget>[
            _AccountTile(
              icon: Icons.alternate_email,
              label: 'Email',
              value: email ?? (principal.email.isEmpty ? '…' : principal.email),
              status: switch (emailVerified) {
                null => null,
                true => (text: 'Verified', good: true),
                false => (text: 'Not verified', good: false),
              },
              onTap: () => context.go('/profile'),
            ),
            if (viaGoogle)
              _AccountTile(
                icon: Icons.account_circle_outlined,
                label: 'Google account',
                value: switch (profile) {
                  GoogleProfileLoaded(:final user) => user.name,
                  _ => '…',
                },
                status: (text: 'Signs in with Google', good: true),
                onTap: () => context.go('/profile'),
              )
            else
              _TwoFactorTile(profile: profile),
            _AccountTile(
              icon: Icons.badge_outlined,
              label: 'Role',
              value: roleLabel(principal.role),
              status: null,
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
        if (profile is ProfileUnavailable) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Your account details could not be read just now.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.person_outline),
              label: const Text('Your profile'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/profile/security'),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Security'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Whether a second factor protects a person's account.
class _TwoFactorTile extends StatelessWidget {
  const _TwoFactorTile({required this.profile});

  final ProfileState profile;

  @override
  Widget build(BuildContext context) {
    final person = switch (profile) {
      ProfileLoaded(:final person) => person,
      _ => null,
    };

    return _AccountTile(
      icon: Icons.shield_outlined,
      label: 'Two-factor authentication',
      value: switch (person) {
        null => '…',
        Person(twoFactorEnabled: true) => 'On',
        _ => 'Off',
      },
      status: switch (person) {
        null => null,
        Person(twoFactorEnabled: true) => (text: 'Protected', good: true),
        _ => (text: 'Not set up', good: false),
      },
      onTap: () => context.go('/profile/security'),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final ({String text, bool good})? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              _TileIcon(
                icon: icon,
                background: scheme.secondaryContainer,
                foreground: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (status case (:final text, :final good))
                      Text(
                        text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: good ? scheme.tertiary : scheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
