import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/session.dart';
import 'email_verification_controller.dart';
import 'session_controller.dart';

/// The email verification screen, opened by the link mailed at person creation.
///
/// It verifies on open rather than waiting for a tap: the user already acted by
/// following the link, and asking them to confirm it twice adds nothing.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({required this.token, super.key});

  /// The token from `?token=…`, or `null` when the link carried none.
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(emailVerificationControllerProvider.notifier)
            .verify(widget.token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(emailVerificationControllerProvider);
    final authenticated = ref.watch(sessionControllerProvider) is Authenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ...switch (state.verification) {
                    Verifying() => <Widget>[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                      Text(
                        'Checking your link…',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    Verified(:final messages) => _verified(
                      context,
                      theme,
                      messages,
                      authenticated: authenticated,
                    ),
                    // AF-05b: the token is no good and cannot be corrected
                    // here, so the resend below is the way on.
                    VerifyRejected(:final failure) => <Widget>[
                      Text(
                        'That link did not work',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      if (failure.kind == FailureKind.network)
                        RetryBanner(
                          onRetry: () => ref
                              .read(
                                emailVerificationControllerProvider.notifier,
                              )
                              .verify(widget.token),
                        )
                      else
                        ErrorBanner(failure: failure),
                    ],
                    // AF-05a: no token, so nothing was ever sent.
                    VerifyIdle() => <Widget>[
                      Text(
                        'This link is incomplete',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'It carries no verification token, so there is nothing '
                        'to confirm. Ask for a fresh email below.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  },
                  // AF-05a and AF-05b both end here: the resend is what makes
                  // either recoverable.
                  if (state.verification is! Verified) ...<Widget>[
                    const SizedBox(height: 24),
                    _ResendSection(authenticated: authenticated),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The success state, which AF-05d shares with the main flow.
  ///
  /// The API's own `messages` are shown when it sent any, because "already
  /// verified" and "now verified" are both successes and only its wording
  /// separates them.
  List<Widget> _verified(
    BuildContext context,
    ThemeData theme,
    List<String> messages, {
    required bool authenticated,
  }) => <Widget>[
    Icon(
      Icons.mark_email_read_outlined,
      size: 48,
      color: theme.colorScheme.primary,
    ),
    const SizedBox(height: 16),
    Text('Your email is verified', style: theme.textTheme.headlineMedium),
    const SizedBox(height: 8),
    for (final message in messages)
      Text(message, style: theme.textTheme.bodyMedium),
    if (messages.isEmpty)
      Text(
        'Your address is confirmed. Nothing else is needed.',
        style: theme.textTheme.bodyMedium,
      ),
    const SizedBox(height: 24),
    // Onward to the home screen when a session exists, and to sign-in
    // otherwise — someone following a link from their mail client usually
    // holds neither.
    FilledButton(
      onPressed: () => context.go(authenticated ? '/' : '/login'),
      child: Text(authenticated ? 'Continue' : 'Sign in'),
    ),
  ];
}

/// AF-05c — the resend action, and what to do when it is not available.
///
/// The API reads the person from the bearer token, so only a signed-in caller
/// can ask for a fresh email. An anonymous one is sent to sign in rather than
/// offered a control that could only answer 401.
class _ResendSection extends ConsumerWidget {
  const _ResendSection({required this.authenticated});

  final bool authenticated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resend = ref.watch(emailVerificationControllerProvider).resend;

    if (!authenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Sign in to ask for a new verification email — we send it to the '
            'address on your account, so we need to know whose it is.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      );
    }

    return switch (resend) {
      ResendSent() => Text(
        'A new verification email is on its way. Check your inbox.',
        style: theme.textTheme.bodyMedium,
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (resend case ResendRejected(:final failure)) ...<Widget>[
            if (failure.kind == FailureKind.network)
              RetryBanner(
                onRetry: () => ref
                    .read(emailVerificationControllerProvider.notifier)
                    .resend(),
              )
            else
              ErrorBanner(failure: failure),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: resend is Resending
                ? null
                : () => ref
                      .read(emailVerificationControllerProvider.notifier)
                      .resend(),
            child: resend is Resending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send a new email'),
          ),
        ],
      ),
    };
  }
}
