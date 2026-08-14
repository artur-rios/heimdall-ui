import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/result/result.dart';
import 'session_controller.dart';

/// What activating the Google sign-in control does.
///
/// UI-01 owns the control's placement and whether it is offered at all; the
/// exchange behind it belongs to UI-06, which overrides this. Until then the
/// control says so rather than failing silently.
typedef GoogleSignInAction = Future<void> Function(BuildContext context);

final Provider<GoogleSignInAction> googleSignInActionProvider =
    Provider<GoogleSignInAction>(
      (ref) => (context) async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in is not available yet.')),
        );
      },
    );

/// The sign-in screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Failure? _failure;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
      _failure = result.failureOrNull;

      if (_failure case final Failure failure
          when failure.kind != FailureKind.network) {
        // AF-01a: keep the address, drop the secret. A transport failure is
        // not a rejection, so the input survives it and Retry can resend.
        _password.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Heimdall', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (_failure case final Failure failure) ...<Widget>[
                      if (failure.kind == FailureKind.network)
                        // AF-01d: nothing was rejected, so the only useful
                        // action is to try the same submission again.
                        _RetryBanner(onRetry: _submitting ? null : _submit)
                      else
                        _ErrorBanner(failure: failure),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _email,
                      autofillHints: const <String>[AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const <String>[AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) =>
                          (value ?? '').isEmpty ? 'Enter your password.' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                    // AF-01e: the control the login screen offers alongside the
                    // credentials form. AF-06a hides it entirely when the build
                    // carries no Google client id.
                    if (ref
                        .watch(appConfigProvider)
                        .isGoogleSignInConfigured) ...<Widget>[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () =>
                                  ref.read(googleSignInActionProvider)(context),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Continue with Google'),
                      ),
                    ],
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

/// Says that the API could not be reached, and offers the only action that
/// helps. The API returns no errors for a transport failure, so there is
/// nothing of its own to render here.
class _RetryBanner extends StatelessWidget {
  const _RetryBanner({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Could not reach the API. Check your connection and try again.',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      ),
    );
  }
}

/// Shows the API's own error strings, unaltered.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messages = failure.errors.isNotEmpty
        ? failure.errors
        : <String>[failure.displayMessage];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final message in messages)
            Text(message, style: TextStyle(color: scheme.onErrorContainer)),
        ],
      ),
    );
  }
}
