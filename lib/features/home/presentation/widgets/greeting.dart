import 'package:flutter/material.dart';

import '../../../auth/domain/session.dart';
import '../role_label.dart';

class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.principal});

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
