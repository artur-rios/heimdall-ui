import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/person.dart';
import 'account_emails_controller.dart';

/// UI-36 — has a fresh verification link or a password reset link mailed to
/// the person's own address. Nothing is shown here but the outcome: the link
/// goes to them alone.
class AccountEmailsCard extends ConsumerWidget {
  const AccountEmailsCard({
    required this.person,
    this.onVerificationRefused,
    super.key,
  });

  final Person person;

  /// AF-36c — called when the API says the address is already verified, so
  /// the screen can reload the person and drop the action.
  final VoidCallback? onVerificationRefused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountEmailsControllerProvider(person.id));
    final controller = ref.read(
      accountEmailsControllerProvider(person.id).notifier,
    );
    final theme = Theme.of(context);

    Future<void> send(AccountEmail kind, String question) async {
      final confirmed = await showConfirm(
        context: context,
        title: question,
        message:
            'The link goes only to their own address. No link or code is '
            'shown here.',
        confirmLabel: 'Send',
      );

      if (!confirmed) {
        return;
      }

      await controller.send(kind);

      // The card may have gone while the request was in flight (the person
      // navigated away); its ref is unusable then. The controller outlives
      // the card, so its own state update is safe.
      if (!context.mounted) {
        return;
      }

      if (kind == AccountEmail.verification &&
          ref.read(accountEmailsControllerProvider(person.id)).failure?.kind ==
              FailureKind.validation) {
        onVerificationRefused?.call();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Account emails', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Links go only to the person\'s own address; none is ever '
              'shown here.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (state.failure case final Failure failure) ...<Widget>[
              ErrorBanner(failure: failure),
              const SizedBox(height: 12),
            ],
            if (state.sent != null) ...<Widget>[
              Text('Sent to ${person.email}.'),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                if (!person.emailVerified)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.mark_email_unread_outlined),
                    label: const Text('Resend verification email'),
                    onPressed: state.sending != null
                        ? null
                        : () => send(
                            AccountEmail.verification,
                            'Send a new verification link to ${person.email}?',
                          ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: const Text('Send password reset'),
                  onPressed: state.sending != null
                      ? null
                      : () => send(
                          AccountEmail.passwordReset,
                          'Send a password reset link to ${person.email}?',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
