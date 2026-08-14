import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/failure_banner.dart';
import 'password_reset_controller.dart';

/// The password reset screen, opened by the link mailed in UI-03.
///
/// The token is the whole credential here, so the screen has nothing to do
/// without one — which is why AF-04a is a distinct state rather than a
/// validation message on the form.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({required this.token, super.key});

  /// The token from `?token=…`, or `null` when the link carried none.
  final String? token;

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = widget.token;

    if (token == null || token.isEmpty) {
      return;
    }

    // AF-04c: the confirmation must match before anything is sent.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (ref.read(passwordResetControllerProvider) is ResetSubmitting) {
      return;
    }

    await ref
        .read(passwordResetControllerProvider.notifier)
        .submit(token: token, newPassword: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = widget.token;
    final state = ref.watch(passwordResetControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (state) {
                // AF-04a: no token, nothing to reset. The only useful action is
                // to ask for a link that carries one.
                _ when token == null || token.isEmpty =>
                  const _IncompleteLink(),
                ResetSucceeded() => const _Confirmation(),
                _ => _buildForm(context, theme, state),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ThemeData theme,
    PasswordResetState state,
  ) {
    final submitting = state is ResetSubmitting;
    final failure = state is ResetFailed ? state.failure : null;
    final rejected = failure != null && failure.kind != FailureKind.network;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Set a new password', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Choose a new password for your account.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (failure != null) ...<Widget>[
            if (failure.kind == FailureKind.network)
              RetryBanner(onRetry: submitting ? null : _submit)
            else
              ErrorBanner(failure: failure),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _password,
            obscureText: true,
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              // AF-04d: a password the policy refuses is the API's answer about
              // this field, so it is marked as well as banner-ed.
              errorText: rejected ? failure.displayMessage : null,
            ),
            validator: (value) =>
                (value ?? '').isEmpty ? 'Enter a new password.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Confirm password'),
            onFieldSubmitted: (_) => _submit(),
            // AF-04c: mismatched entries never reach the API.
            validator: (value) =>
                value == _password.text ? null : 'The passwords do not match.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting ? null : _submit,
            child: submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Set password'),
          ),
          // AF-04b: a token the API will not accept cannot be corrected here,
          // so the way forward is a new link rather than another attempt.
          if (rejected) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: submitting
                  ? null
                  : () => context.go('/password-recovery'),
              child: const Text('Request a new link'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: submitting ? null : () => context.go('/login'),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}

/// AF-04a — the link arrived without a token, so there is no form to show.
class _IncompleteLink extends StatelessWidget {
  const _IncompleteLink();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.link_off_outlined, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text('This link is incomplete', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'It carries no reset token, so there is nothing to set a password '
          'against. Mail clients sometimes cut long links short — requesting a '
          'new one is the quickest way through.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/password-recovery'),
          child: const Text('Request a new link'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}

/// The password was changed, and signing in is the only thing left to do.
class _Confirmation extends StatelessWidget {
  const _Confirmation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.lock_reset_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text('Your password is set', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Sign in with your new password to continue.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}
