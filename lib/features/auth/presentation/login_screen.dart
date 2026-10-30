import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/result/result.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../../../shared/widgets/page_title.dart';
import '../domain/google_sign_in_gateway.dart';
import '../domain/session.dart';
import 'credential_field.dart';
import 'google_sign_in_control.dart';
import 'session_controller.dart';

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
    // Enter in a field submits too, and the disabled button does not cover
    // that path: a second press must not send a second attempt.
    if (_submitting) {
      return;
    }

    if (!validateAndReveal(_formKey)) {
      return;
    }

    // Lets a password manager offer to save what was just used.
    announceCredentialsSubmitted();

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

    return PageTitle(
      title: 'Sign in',
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  // Off the web the platform's autofill service reads the
                  // credentials as one group. On the web the fields are real
                  // HTML inputs in one form instead: see [CredentialField].
                  child: AutofillGroup(
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
                        // AF-07e: the token was rejected mid-session. Saying so
                        // beats leaving the user to wonder why their work stopped.
                        if (ref.watch(sessionControllerProvider)
                            case Unauthenticated(
                              sessionExpired: true,
                            )) ...<Widget>[
                          const Notice(
                            'Your session ended. Sign in again to pick up where '
                            'you left off.',
                            icon: Icons.info_outline,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // UI-30: the restriction was lifted from a token that stays
                        // confined to the rights endpoints, so a fresh sign-in is
                        // what brings full access back.
                        if (ref.watch(sessionControllerProvider)
                            case Unauthenticated(
                              restrictionLifted: true,
                            )) ...<Widget>[
                          const Notice(
                            'The restriction on processing your account is lifted. '
                            'Sign in again for full access.',
                            icon: Icons.info_outline,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // UI-33: the person has just restricted processing of
                        // their account, so a fresh sign-in opens the restricted
                        // session (UI-30), not the one they had.
                        if (ref.watch(sessionControllerProvider)
                            case Unauthenticated(
                              processingRestricted: true,
                            )) ...<Widget>[
                          const Notice(
                            'Processing of your account is restricted, and your '
                            'account is suspended until the restriction is '
                            'lifted. Sign in again to lift it, or to download or '
                            'erase your data.',
                            icon: Icons.info_outline,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // UI-08, UI-09: the person changed their own sign-in
                        // details, which ended every session they had, this one
                        // included.
                        if (ref.watch(sessionControllerProvider)
                            case Unauthenticated(
                              credentialsChanged: true,
                            )) ...<Widget>[
                          const Notice(
                            'Your sign-in details changed. Sign in again.',
                            icon: Icons.info_outline,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_failure case final Failure failure) ...<Widget>[
                          if (failure.kind == FailureKind.network)
                            // AF-01d: nothing was rejected, so the only useful
                            // action is to try the same submission again.
                            RetryBanner(onRetry: _submitting ? null : _submit)
                          else
                            ErrorBanner(failure: failure),
                          const SizedBox(height: 16),
                        ],
                        CredentialField(
                          kind: CredentialKind.email,
                          controller: _email,
                          label: 'Email',
                          enabled: !_submitting,
                          validator: (value) {
                            final email = value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Enter your email address.';
                            }

                            return isPlausibleEmail(email)
                                ? null
                                : 'Enter a valid email address.';
                          },
                        ),
                        const SizedBox(height: 16),
                        CredentialField(
                          kind: CredentialKind.password,
                          controller: _password,
                          label: 'Password',
                          enabled: !_submitting,
                          onSubmitted: _submit,
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Enter your password.'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: 8),
                        // UI-03 step 1: the recovery screen is reached from here,
                        // which is the only place someone who cannot sign in is.
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => context.go('/password-recovery'),
                          child: const Text('Forgot your password?'),
                        ),
                        // AF-01e: the control the login screen offers alongside the
                        // credentials form. AF-06a hides it when the build carries
                        // no Google client id, and AF-06e when the target cannot
                        // run the flow — both inside the control itself.
                        if (ref
                                .watch(appConfigProvider)
                                .isGoogleSignInConfigured &&
                            ref
                                    .watch(googleSignInGatewayProvider)
                                    .availability !=
                                GoogleSignInAvailability
                                    .unsupported) ...<Widget>[
                          const SizedBox(height: 16),
                          GoogleSignInControl(enabled: !_submitting),
                        ],
                        const SizedBox(height: 8),
                        // Issue #73: beside the Google control, because Google's
                        // consent screen names this page as the privacy policy. It
                        // stays when that control is hidden: what is held about a
                        // person does not depend on how they sign in.
                        TextButton(
                          onPressed: () => context.push('/privacy'),
                          child: const Text('Privacy notice'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
