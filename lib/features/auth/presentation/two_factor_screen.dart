import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/session.dart';
import 'session_controller.dart';

/// How long the resend control waits after each send.
const Duration resendCooldown = Duration(seconds: 30);

/// The API's reissue cap for one challenge (FR-2F-13). Further sends would be
/// answered alike and send nothing, so the control stops offering them.
const int maxCodeResends = 3;

/// Whether [method] is the email method, whatever the API called it.
bool _isEmail(String? method) => switch (method?.toLowerCase()) {
  'email' || 'mail' => true,
  _ => false,
};

/// The second-factor challenge screen.
///
/// Reachable only while the session holds a challenge: the moment the challenge
/// ends — answered, abandoned, or refused — the router takes the user onward,
/// so this screen never has to navigate for itself.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  Failure? _failure;
  bool _submitting = false;
  bool _useRecoveryCode = false;

  // The resend count belongs to the challenge, not to the method or the
  // recovery-code toggle, so nothing below resets it.
  int _sends = 0;
  int _cooldownLeft = 0;
  Timer? _cooldown;
  bool _resending = false;
  bool _resent = false;
  Failure? _resendFailure;

  @override
  void dispose() {
    _cooldown?.cancel();
    _code.dispose();
    super.dispose();
  }

  /// AF-02e: leaving ends the challenge. The token is dropped rather than kept
  /// for a return, because it was never persisted in the first place.
  void _abandon() {
    ref.read(sessionControllerProvider.notifier).abandonChallenge();
  }

  /// UI-02 — another email code for this challenge. The API answers alike
  /// whether or not it sent one, so the confirmation never claims more than
  /// that; a failure to reach it is not a send and costs nothing (AF-02h).
  Future<void> _resend() async {
    if (_resending || _cooldownLeft > 0 || _sends >= maxCodeResends) {
      return;
    }

    setState(() {
      _resending = true;
      _resendFailure = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .resendSecondFactorCode();

    if (!mounted) {
      return;
    }

    setState(() {
      _resending = false;

      if (result.failureOrNull case final Failure failure) {
        _resendFailure = failure;

        return;
      }

      _sends++;
      _resent = true;
      _cooldownLeft = resendCooldown.inSeconds;
    });

    if (result.isSuccess) {
      _cooldown?.cancel();
      _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();

          return;
        }

        setState(() => _cooldownLeft--);

        if (_cooldownLeft <= 0) {
          timer.cancel();
        }
      });
    }
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

    setState(() {
      _submitting = true;
      _failure = null;
    });

    final usedRecoveryCode = _useRecoveryCode;
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .submitSecondFactor(
          _code.text.trim(),
          isRecoveryCode: usedRecoveryCode,
        );

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final challengeSurvived = ref.read(sessionControllerProvider) is Challenged;

    if (result.isSuccess) {
      // AF-02d: a recovery code is spent by using it. The reminder rides on the
      // messenger rather than this screen, which the router is already leaving.
      if (usedRecoveryCode) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'That recovery code has now been used. Generate new codes in '
              'your security settings.',
            ),
          ),
        );
      }

      return;
    }

    // AF-02b: the challenge is gone, so there is nothing left to correct here.
    if (!challengeSurvived) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That sign-in attempt expired. Please sign in again.'),
        ),
      );

      return;
    }

    setState(() {
      _submitting = false;
      _failure = result.failureOrNull;

      // AF-02a: the code was wrong, so it is worth nothing; a transport failure
      // rejected nothing, so what was typed survives and Retry can resend it.
      if (_failure case final Failure failure
          when failure.kind != FailureKind.network) {
        _code.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);

    // The challenge has ended and the router is moving on. Showing the form
    // again here would invite a code that has nowhere to go.
    if (session is! Challenged) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final method = session.methodInUse;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _abandon();
        }
      },
      child: Scaffold(
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
                      Text(
                        'Two-step verification',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _useRecoveryCode
                            ? 'Enter one of your recovery codes.'
                            : _promptFor(method),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (_failure case final Failure failure) ...<Widget>[
                        if (failure.kind == FailureKind.network)
                          RetryBanner(onRetry: _submitting ? null : _submit)
                        else
                          ErrorBanner(failure: failure),
                        const SizedBox(height: 16),
                      ],
                      // AF-02c: only worth showing when there is a choice to
                      // make. A recovery code answers any of them.
                      if (session.availableMethods.length > 1 &&
                          !_useRecoveryCode) ...<Widget>[
                        SegmentedButton<String>(
                          segments: <ButtonSegment<String>>[
                            for (final available in session.availableMethods)
                              ButtonSegment<String>(
                                value: available,
                                label: Text(_labelFor(available)),
                              ),
                          ],
                          selected: <String>{?method},
                          emptySelectionAllowed: true,
                          onSelectionChanged: _submitting
                              ? null
                              : (selection) {
                                  ref
                                      .read(sessionControllerProvider.notifier)
                                      .chooseMethod(selection.first);
                                },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _code,
                        keyboardType: _useRecoveryCode
                            ? TextInputType.text
                            : TextInputType.number,
                        autofillHints: const <String>[
                          AutofillHints.oneTimeCode,
                        ],
                        decoration: InputDecoration(
                          labelText: _useRecoveryCode
                              ? 'Recovery code'
                              : 'Verification code',
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if ((value ?? '').trim().isNotEmpty) {
                            return null;
                          }

                          return _useRecoveryCode
                              ? 'Enter a recovery code.'
                              : 'Enter your verification code.';
                        },
                      ),
                      const SizedBox(height: 24),
                      if (_isEmail(method) && !_useRecoveryCode) ...<Widget>[
                        if (_resent) ...<Widget>[
                          Text(
                            'If your sign-in is still open, a new code is on '
                            'its way. Codes sent before it no longer work.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_resendFailure
                            case final Failure failure) ...<Widget>[
                          ErrorBanner(failure: failure),
                          const SizedBox(height: 8),
                        ],
                        // AF-02g: past the API's cap a send would do nothing,
                        // so the way to a new code is a new sign-in.
                        if (_sends >= maxCodeResends) ...<Widget>[
                          Text(
                            'For another code, sign in again.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _submitting ? null : _abandon,
                            child: const Text('Start over'),
                          ),
                        ] else
                          TextButton(
                            onPressed:
                                (_submitting || _resending || _cooldownLeft > 0)
                                ? null
                                : _resend,
                            child: Text(
                              _cooldownLeft > 0
                                  ? 'Send a new code (${_cooldownLeft}s)'
                                  : 'Send a new code',
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Verify'),
                      ),
                      const SizedBox(height: 8),
                      // AF-02d: available whatever the API offered, since a
                      // recovery code exists precisely for when the others
                      // cannot be reached.
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() {
                                _useRecoveryCode = !_useRecoveryCode;
                                _code.clear();
                                _failure = null;
                              }),
                        child: Text(
                          _useRecoveryCode
                              ? 'Use a verification code instead'
                              : 'Use a recovery code instead',
                        ),
                      ),
                      TextButton(
                        onPressed: _submitting ? null : _abandon,
                        child: const Text('Back to sign in'),
                      ),
                    ],
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

/// Names a method the way its owner would. An unrecognised one is shown as the
/// API worded it, which beats guessing.
String _labelFor(String method) => switch (method.toLowerCase()) {
  'totp' || 'app' || 'authenticator' || 'authenticatorapp' => 'Authenticator',
  'email' || 'mail' => 'Email',
  _ => method,
};

/// What to tell the user to reach for, given the method in use.
String _promptFor(String? method) => switch (method?.toLowerCase()) {
  'totp' ||
  'app' ||
  'authenticator' ||
  'authenticatorapp' => 'Enter the code from your authenticator app.',
  'email' || 'mail' => 'Enter the code we sent to your email address.',
  null => 'Enter your verification code.',
  _ => 'Enter your verification code for $method.',
};
