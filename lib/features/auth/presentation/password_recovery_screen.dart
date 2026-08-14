import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/widgets/failure_banner.dart';
import 'password_recovery_controller.dart';

/// The password recovery screen.
///
/// Everything it can say is deliberately the same for an address that exists
/// and one that does not: the confirmation is the only success, and it names
/// nobody.
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // AF-03a: an empty or malformed address never reaches the API.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // AF-03c: the control is already disabled while a request is in flight;
    // this makes a submission from the keyboard obey the same rule.
    if (ref.read(passwordRecoveryControllerProvider) is RecoverySending) {
      return;
    }

    await ref
        .read(passwordRecoveryControllerProvider.notifier)
        .request(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(passwordRecoveryControllerProvider);
    final sending = state is RecoverySending;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Reset your password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: state is RecoverySent
                  ? _Confirmation(onBackToSignIn: () => context.go('/login'))
                  : Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Forgot your password?',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your email address and we will send you a '
                            'link to set a new password.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          if (state is RecoveryFailed) ...<Widget>[
                            if (state.failure.kind == FailureKind.network)
                              // AF-03b: nothing was sent, so the same
                              // submission is worth making again.
                              RetryBanner(onRetry: sending ? null : _submit)
                            else
                              ErrorBanner(failure: state.failure),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _email,
                            autofillHints: const <String>[AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Enter your email address.';
                              }

                              return email.contains('@')
                                  ? null
                                  : 'Enter a valid email address.';
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: sending ? null : _submit,
                            child: sending
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Send reset link'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: sending
                                ? null
                                : () => context.go('/login'),
                            child: const Text('Back to sign in'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one thing a successful request ever says.
///
/// It does not repeat the address back, and it is worded so that it reads the
/// same whether or not anyone is registered under it — which is the point.
class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.onBackToSignIn});

  final VoidCallback onBackToSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.mark_email_read_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text('Check your inbox', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'If that address belongs to an account, a link to set a new password '
          'is on its way. It expires shortly, so use it soon.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onBackToSignIn,
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
