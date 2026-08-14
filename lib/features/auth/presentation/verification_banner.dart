import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/session.dart';
import 'email_verification_controller.dart';
import 'session_controller.dart';

/// Whether the prompt has been dismissed for this session.
///
/// AF-05e calls the banner dismissible, and a dismissal that a rebuild undoes
/// is not one. It lives here rather than in the widget so navigating away and
/// back does not bring the banner straight back.
final NotifierProvider<VerificationBannerDismissal, bool>
verificationBannerDismissedProvider =
    NotifierProvider<VerificationBannerDismissal, bool>(
      VerificationBannerDismissal.new,
    );

class VerificationBannerDismissal extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() {
    state = true;
  }
}

/// AF-05e — the prompt an authenticated user with an unverified address sees.
///
/// Renders nothing at all when there is nothing to say, so the caller can place
/// it unconditionally.
class VerificationBanner extends ConsumerWidget {
  const VerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session is! Authenticated || session.principal.emailVerified) {
      return const SizedBox.shrink();
    }

    if (ref.watch(verificationBannerDismissedProvider)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resend = ref.watch(emailVerificationControllerProvider).resend;

    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.mark_email_unread_outlined,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: switch (resend) {
                ResendSent() => Text(
                  'A new verification email is on its way.',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
                ResendRejected(:final failure) => Text(
                  failure.displayMessage,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
                _ => Text(
                  'Your email address is not verified yet.',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              },
            ),
            if (resend is! ResendSent)
              TextButton(
                onPressed: resend is Resending
                    ? null
                    : () => ref
                          .read(emailVerificationControllerProvider.notifier)
                          .resend(),
                child: const Text('Resend'),
              ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close),
              onPressed: () => ref
                  .read(verificationBannerDismissedProvider.notifier)
                  .dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}
