import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/dashboard.dart';

/// Each summarised scope, with what it holds, one tap from its detail.
class ScopeBreakdown extends StatelessWidget {
  const ScopeBreakdown({super.key, required this.summaries});

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
