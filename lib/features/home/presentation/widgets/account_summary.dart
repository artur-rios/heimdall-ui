import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/session.dart';
import '../../../persons/domain/person.dart';
import '../../../profile/presentation/profile_controller.dart';
import '../role_label.dart';
import 'stat_grid.dart';
import 'tile_icon.dart';

/// The signed-in person's own account: who they are, how well it is
/// protected, and the way to change either.
///
/// A Google session's account is its Google User record (#133): the name and
/// address Google reported, in place of the second factor, which a Google User
/// may never configure.
class AccountSummary extends ConsumerWidget {
  const AccountSummary({
    super.key,
    required this.principal,
    required this.viaGoogle,
  });

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
        StatGrid(
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
              TileIcon(
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
