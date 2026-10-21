import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/formatting/date_time_format.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../domain/scope_invitation.dart';
import 'scope_invitations_controller.dart';

/// UI-39 — the signed-in administrator's open invitations to co-own a scope,
/// on Home, with Accept and Decline. Shown only while there is something to
/// show (AF-39a, AF-39e).
class ScopeInvitationsCard extends ConsumerWidget {
  const ScopeInvitationsCard({this.onAccepted, super.key});

  /// Called once an acceptance went through, so the screen around the card can
  /// read again what the new ownership changes.
  final VoidCallback? onAccepted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scopeInvitationsControllerProvider);

    if (state is! ScopeInvitationsLoaded || !state.isVisible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final controller = ref.read(scopeInvitationsControllerProvider.notifier);

    Future<void> accept(ScopeInvitation invitation) async {
      final confirmed = await showConfirm(
        context: context,
        title: 'Accept the invitation to ${invitation.scopeName}?',
        message:
            'You become a co-owner of ${invitation.scopeName} and can manage '
            'it straight away.',
        confirmLabel: 'Accept',
      );

      if (confirmed && await controller.accept(invitation)) {
        onAccepted?.call();
      }
    }

    Future<void> decline(ScopeInvitation invitation) async {
      final confirmed = await showConfirm(
        context: context,
        title: 'Decline the invitation to ${invitation.scopeName}?',
        message:
            'The invitation ends. An owner of ${invitation.scopeName} can '
            'invite you again.',
        confirmLabel: 'Decline',
      );

      if (confirmed) {
        await controller.decline(invitation);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Scope invitations', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'You were invited to co-own these scopes. Nothing changes '
                'until you accept.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // AF-39c, AF-39d: the API's own words.
              if (state.failure case final failure?) ...<Widget>[
                const SizedBox(height: 12),
                ErrorBanner(failure: failure),
              ],
              if (state.notice case final notice?) ...<Widget>[
                const SizedBox(height: 12),
                Notice(notice),
              ],
              for (final invitation in state.invitations) ...<Widget>[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: Text(invitation.scopeName),
                  subtitle: Text(_details(context, invitation)),
                ),
                // An OverflowBar rather than a Row: on a narrow window the two
                // answers wrap instead of overflowing.
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: <Widget>[
                    TextButton(
                      onPressed: state.busy ? null : () => decline(invitation),
                      child: const Text('Decline'),
                    ),
                    FilledButton.tonal(
                      onPressed: state.busy ? null : () => accept(invitation),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Who invited them and when it runs out, whichever is known.
  static String _details(BuildContext context, ScopeInvitation invitation) =>
      <String>[
        if (invitation.invitedByName case final name?) 'Invited by $name',
        if (invitation.expiresAt case final expiresAt?)
          'Expires ${formatDateTime(context, expiresAt)}',
      ].join(' · ');
}
