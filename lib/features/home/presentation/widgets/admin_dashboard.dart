import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/collection_states.dart';
import '../../domain/dashboard.dart';
import '../dashboard_controller.dart';
import 'scope_breakdown.dart';
import 'section_title.dart';
import 'stat_grid.dart';
import 'stat_tile.dart';

/// The figures, then each scope's breakdown.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({
    super.key,
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
        SectionTitle('Overview'),
        SizedBox(height: 12),
        StatGrid(
          children: <Widget>[
            StatTile.loading(label: 'Scopes', icon: Icons.domain_outlined),
            StatTile.loading(label: 'Persons', icon: Icons.people_outline),
            StatTile.loading(label: 'Applications', icon: Icons.apps_outlined),
            StatTile.loading(label: 'Permissions', icon: Icons.key_outlined),
          ],
        ),
      ],
    ),
    DashboardFailed(:final failure) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionTitle('Overview'),
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
        SectionTitle(
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
        StatGrid(
          children: <Widget>[
            StatTile(
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
            StatTile(
              label: 'Persons',
              icon: Icons.people_outline,
              value: _figure(stats.persons),
              tooltip: stats.persons == null ? 'Could not be read' : null,
              caption: 'Users in your scopes',
            ),
            StatTile(
              label: 'Applications',
              icon: Icons.apps_outlined,
              value: _figure(stats.applications),
              tooltip: stats.applications == null ? 'Could not be read' : null,
              caption: 'Registered in your scopes',
            ),
            StatTile(
              label: 'Permissions',
              icon: Icons.key_outlined,
              value: _figure(stats.permissions),
              tooltip: stats.permissions == null ? 'Could not be read' : null,
              caption: 'Defined in your scopes',
            ),
            StatTile(
              label: 'Google users',
              icon: Icons.account_circle_outlined,
              value: _figure(stats.googleUsers),
              tooltip: stats.googleUsers == null ? 'Could not be read' : null,
              caption:
                  'Sign-In on in ${stats.googleSignInScopes} of '
                  '$scopeCount ${scopeCount == 1 ? 'scope' : 'scopes'}',
            ),
            if (isSystemAdmin)
              StatTile(
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
        SectionTitle(
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
          ScopeBreakdown(summaries: stats.scopes),
      ],
    );
  }
}

/// How a count reads on a tile: the number, or a dash when it could not be
/// read.
String _figure(int? value) => value == null ? '—' : '$value';

/// Whether the API answered its liveness check, and the way to the full
/// health report.
class _ApiStatusTile extends StatelessWidget {
  const _ApiStatusTile({required this.reachable});

  final bool? reachable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final up = reachable ?? false;

    return StatTile(
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
