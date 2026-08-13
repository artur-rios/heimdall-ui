import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import 'session_controller.dart';

/// The sign-in screen.
///
/// Deliberately minimal: UI-01 completes it with the Google control, the
/// recovery link, and the rest of its alternative flows. What is here is what
/// the shell needs to be reachable at all.
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

      if (_failure != null) {
        // Keep the address, drop the secret.
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
                    if (_failure != null) ...<Widget>[
                      _ErrorBanner(failure: _failure!),
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
