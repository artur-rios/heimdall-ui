import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/qr_code.dart';
import '../../auth/domain/two_factor.dart';
import 'two_factor_controller.dart';

/// UI-09 — two-factor authentication and recovery codes.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(twoFactorControllerProvider.notifier).load(),
    );
  }

  TwoFactorController get _controller =>
      ref.read(twoFactorControllerProvider.notifier);

  /// AF-09c — the codes are shown once, so leaving before acknowledging them
  /// is stopped rather than merely discouraged.
  Future<bool> _mayLeave() async {
    if (ref.read(twoFactorControllerProvider) is! TwoFactorCodesIssued) {
      return true;
    }

    return showConfirm(
      context: context,
      title: 'Leave without your recovery codes?',
      message:
          'These codes are shown once and cannot be retrieved. If you '
          'leave now you will not see them again, and you would have to '
          'generate a new set.',
      confirmLabel: 'Leave anyway',
      cancelLabel: 'Stay',
    );
  }

  /// Leaves for the profile, once AF-09c is satisfied.
  Future<void> _leave() async {
    if (!await _mayLeave()) {
      return;
    }

    _controller.acknowledgeCodes();

    if (mounted) {
      context.go('/profile');
    }
  }

  Future<void> _disable() async {
    final credential = await showDialog<_Credential>(
      context: context,
      builder: (context) => const _CredentialDialog(
        title: 'Turn two-factor authentication off?',
        message:
            'Your account will be protected by its password alone. '
            'Confirm with any one of the following.',
        confirmLabel: 'Turn off',
      ),
    );

    if (credential != null && mounted) {
      await _controller.disable(
        password: credential.password,
        code: credential.code,
        recoveryCode: credential.recoveryCode,
      );
    }
  }

  Future<void> _regenerate() async {
    final credential = await showDialog<_Credential>(
      context: context,
      builder: (context) => const _CredentialDialog(
        title: 'Generate new recovery codes?',
        message:
            'The codes you have now stop working immediately. The new '
            'set is shown once. Confirm with any one of the following.',
        confirmLabel: 'Generate',
        allowPassword: false,
      ),
    );

    if (credential != null && mounted) {
      await _controller.regenerateRecoveryCodes(
        code: credential.code,
        recoveryCode: credential.recoveryCode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(twoFactorControllerProvider);

    return PopScope(
      // AF-09c: a system back gesture is a way off the screen too.
      canPop: state is! TwoFactorCodesIssued,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _mayLeave() && mounted) {
          _controller.acknowledgeCodes();
        }
      },
      child: AppShell(
        currentRoute: '/profile',
        title: const Text('Security'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Back to your profile',
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
        ],
        body: switch (state) {
          TwoFactorLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          // A Google User may never configure a second factor, which is a
          // fact about the account rather than something to retry.
          TwoFactorUnavailable(ineligible: true) => const CollectionEmpty(
            title: 'Not available for this account',
            message:
                'You sign in with Google, which carries its own second '
                'factor. Two-factor authentication is managed there rather '
                'than here.',
            icon: Icons.lock_person_outlined,
          ),
          TwoFactorUnavailable(:final failure) => CollectionFailed(
            failure: failure,
            onRetry: _controller.load,
          ),
          final TwoFactorCodesIssued issued => _RecoveryCodes(
            codes: issued.codes,
            regenerated: issued.regenerated,
            onAcknowledge: _controller.acknowledgeCodes,
          ),
          final TwoFactorConfirming confirming => _Confirm(
            setup: confirming.setup,
            busy: confirming.busy,
            failure: confirming.failure,
            onConfirm: _controller.confirm,
            onAbandon: _controller.abandonSetup,
          ),
          final TwoFactorSettled settled => _Settled(
            state: settled,
            onEnable: _controller.beginSetup,
            onDisable: _disable,
            onRegenerate: _regenerate,
          ),
        },
      ),
    );
  }
}

/// The section at rest: what is configured, and what may be done about it.
class _Settled extends StatelessWidget {
  const _Settled({
    required this.state,
    required this.onEnable,
    required this.onDisable,
    required this.onRegenerate,
  });

  final TwoFactorSettled state;
  final ValueChanged<TwoFactorMethod> onEnable;
  final VoidCallback onDisable;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = state.status;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        if (state.failure case final failure?) ...<Widget>[
          // AF-09d: whatever the API refused, in its own words.
          ErrorBanner(failure: failure),
          const SizedBox(height: 16),
        ],
        Card(
          color: status.isActive
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Icon(
                  status.isActive
                      ? Icons.shield_outlined
                      : Icons.shield_moon_outlined,
                  color: status.isActive
                      ? theme.colorScheme.onSecondaryContainer
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        status.isActive
                            ? 'Two-factor authentication is on'
                            : 'Two-factor authentication is off',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: status.isActive
                              ? theme.colorScheme.onSecondaryContainer
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.isActive
                            ? 'Signing in asks for a code from '
                                  '${_methodsSentence(status.methods)}.'
                            : 'Signing in asks only for your password.',
                        style: TextStyle(
                          color: status.isActive
                              ? theme.colorScheme.onSecondaryContainer
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!status.isActive) ...<Widget>[
          Text('Turn it on', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Choose how you would like to receive the second factor.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final method in TwoFactorMethod.values)
            Card(
              child: ListTile(
                leading: Icon(
                  method == TwoFactorMethod.app
                      ? Icons.qr_code_2_outlined
                      : Icons.mail_outline,
                ),
                title: Text(method.label),
                subtitle: Text(
                  method == TwoFactorMethod.app
                      ? 'Scan a code into an authenticator application.'
                      : 'We email you a code each time you sign in.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: state.busy ? null : () => onEnable(method),
              ),
            ),
        ] else ...<Widget>[
          Text('Recovery codes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            status.remainingRecoveryCodes == 0
                ? 'You have no recovery codes left. Without one you cannot '
                      'get in if your second factor is unavailable.'
                : '${status.remainingRecoveryCodes} unused. Each one works '
                      'once, and they are the way back in if your second '
                      'factor is unavailable.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: state.busy ? null : onRegenerate,
                icon: const Icon(Icons.password_outlined),
                label: const Text('Generate new codes'),
              ),
              OutlinedButton.icon(
                onPressed: state.busy ? null : onDisable,
                icon: const Icon(Icons.shield_moon_outlined),
                label: const Text('Turn off two-factor'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _methodsSentence(List<TwoFactorMethod> methods) {
    if (methods.isEmpty) {
      return 'your configured method';
    }

    return methods.map((method) => method.label.toLowerCase()).join(' or ');
  }
}

/// The setup waiting for its code.
class _Confirm extends StatefulWidget {
  const _Confirm({
    required this.setup,
    required this.busy,
    required this.failure,
    required this.onConfirm,
    required this.onAbandon,
  });

  final TwoFactorSetup setup;
  final bool busy;
  final Failure? failure;
  final ValueChanged<String> onConfirm;
  final VoidCallback onAbandon;

  @override
  State<_Confirm> createState() => _ConfirmState();
}

class _ConfirmState extends State<_Confirm> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    widget.onConfirm(_code.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setup = widget.setup;
    final uri = setup.otpAuthUri;
    final secret = setup.secret;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text(setup.method.label, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          setup.method == TwoFactorMethod.app
              ? 'Add this to your authenticator application, then enter the '
                    'code it shows.'
              : setup.emailCodeSent
              ? 'We have emailed you a code. Enter it below.'
              : 'Enter the code we sent you.',
          style: theme.textTheme.bodyMedium,
        ),
        if (setup.method == TwoFactorMethod.app) ...<Widget>[
          const SizedBox(height: 24),
          // FR-AU-18 and AF-09e: the code is offered when it can be drawn, and
          // the secret is always shown as selectable text — so a code that
          // will not render never blocks the setup.
          if (uri != null && QrCodeView.canRender(uri))
            Center(child: QrCodeView(data: uri))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'The scannable code could not be drawn. Enter the setup key '
                  'below into your authenticator application by hand instead.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (secret != null) _SelectableSecret(secret: secret),
        ],
        const SizedBox(height: 24),
        if (widget.failure case final failure?) ...<Widget>[
          // AF-09a: the code was wrong, and the setup is still alive.
          ErrorBanner(failure: failure),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Code'),
            onFieldSubmitted: (_) => _submit(),
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Enter the code.' : null,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.busy ? null : _submit,
          child: widget.busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
        const SizedBox(height: 8),
        // AF-09b: leaving before confirming keeps the feature off, and the
        // pending secret goes no further than this screen.
        TextButton(
          onPressed: widget.busy ? null : widget.onAbandon,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// The setup key, shown so it can be selected and typed in by hand.
class _SelectableSecret extends StatelessWidget {
  const _SelectableSecret({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Setup key', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: SelectableText(
                    secret,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy setup key',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: secret)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The recovery codes, shown exactly once.
class _RecoveryCodes extends StatelessWidget {
  const _RecoveryCodes({
    required this.codes,
    required this.regenerated,
    required this.onAcknowledge,
  });

  final List<String> codes;
  final bool regenerated;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asText = codes.join('\n');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text('Your recovery codes', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          regenerated
              ? 'These replace your previous codes, which no longer work. '
                    'They are shown once — save them somewhere safe now.'
              : 'Two-factor authentication is on. These codes are shown once '
                    '— save them somewhere safe now. Each one works once, and '
                    'they are the way back in if your second factor is '
                    'unavailable.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              asText,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => Clipboard.setData(ClipboardData(text: asText)),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy codes'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // AF-09c — the only way onward.
        FilledButton(
          onPressed: onAcknowledge,
          child: const Text('I have saved my codes'),
        ),
      ],
    );
  }
}

/// What the disable and regenerate commands need: any one credential.
class _Credential {
  const _Credential({this.password, this.code, this.recoveryCode});

  final String? password;
  final String? code;
  final String? recoveryCode;
}

/// Asks for one of the credentials the API accepts.
///
/// The API takes a password, a generated code, or a recovery code in separate
/// fields, so which one the person supplies decides where it travels.
class _CredentialDialog extends StatefulWidget {
  const _CredentialDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.allowPassword = true,
  });

  final String title;
  final String message;
  final String confirmLabel;

  /// Regenerating accepts only a code or a recovery code, so the password
  /// field is not offered where the API would not take it.
  final bool allowPassword;

  @override
  State<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<_CredentialDialog> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _recoveryCode = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    _recoveryCode.dispose();
    super.dispose();
  }

  /// Exactly what was filled in, and nothing else.
  _Credential? get _credential {
    if (widget.allowPassword && _password.text.isNotEmpty) {
      return _Credential(password: _password.text);
    }

    if (_code.text.trim().isNotEmpty) {
      return _Credential(code: _code.text.trim());
    }

    if (_recoveryCode.text.trim().isNotEmpty) {
      return _Credential(recoveryCode: _recoveryCode.text.trim());
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final credential = _credential;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.message),
            const SizedBox(height: 16),
            if (widget.allowPassword) ...<Widget>[
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Code from your second factor',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recoveryCode,
              decoration: const InputDecoration(labelText: 'Recovery code'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Nothing filled in is nothing to send, so the control says so by
          // staying disabled rather than by letting the API refuse an empty
          // command.
          onPressed: credential == null
              ? null
              : () => Navigator.of(context).pop(credential),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
