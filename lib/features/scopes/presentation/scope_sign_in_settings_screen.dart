import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/edit_mode.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../google_users/domain/google_user_repository.dart';
import '../domain/email_link.dart';
import '../domain/scope.dart';
import 'scope_sign_in_settings_controller.dart';

/// The one-line state of a scope's ways in, for the scope detail's link to
/// UI-31.
String signInSettingsSummary(Scope scope) => <String>[
  scope.googleSignInEnabled ? 'Google on' : 'Google off',
  scope.selfRegistrationEnabled
      ? 'Self-registration on'
      : 'Self-registration off',
  scope.hasCustomEmailLinks ? 'Custom email links' : 'Default email links',
].join(' · ');

/// UI-31 — how people get into one scope: Google Sign-In, self-registration,
/// and where its emails send them.
class ScopeSignInSettingsScreen extends ConsumerStatefulWidget {
  const ScopeSignInSettingsScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<ScopeSignInSettingsScreen> createState() =>
      _ScopeSignInSettingsScreenState();
}

class _ScopeSignInSettingsScreenState
    extends ConsumerState<ScopeSignInSettingsScreen> {
  var _formKey = GlobalKey<FormState>();
  final _verification = TextEditingController();
  final _reset = TextEditingController();

  /// The record the fields were last seeded from.
  Scope? _seeded;

  /// Whether the person has asked to change the links.
  bool _editing = false;

  ScopeSignInSettingsController get _controller =>
      ref.read(scopeSignInSettingsControllerProvider(widget.scopeId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.load());
  }

  @override
  void dispose() {
    _verification.dispose();
    _reset.dispose();
    super.dispose();
  }

  /// Copies a freshly read or freshly saved record into the fields.
  ///
  /// AF-31d and AF-31i: a refused or failed save leaves the scope as it was,
  /// and a toggle elsewhere on the screen replaces it with one whose links are
  /// the same; neither may overwrite what the person is typing.
  void _seed(Scope scope) {
    if (identical(_seeded, scope)) {
      return;
    }

    final previous = _seeded;
    _seeded = scope;

    final linksChanged =
        previous == null ||
        previous.emailVerificationUrl != scope.emailVerificationUrl ||
        previous.passwordResetUrl != scope.passwordResetUrl;

    if (!_editing || linksChanged) {
      _restore(scope);
    }
  }

  void _restore(Scope scope) {
    _verification.text = scope.emailVerificationUrl ?? '';
    _reset.text = scope.passwordResetUrl ?? '';
  }

  void _startEditing() {
    _controller.acknowledgeLinks();
    setState(() => _editing = true);
  }

  /// Puts back what the API holds and leaves edit mode, dropping any refusal
  /// along with the edit it was about.
  void _cancelEditing() {
    _controller.acknowledgeLinks();
    setState(() {
      _editing = false;
      // A fresh key forgets the fields' validation messages too.
      _formKey = GlobalKey<FormState>();

      if (_seeded case final scope?) {
        _restore(scope);
      }
    });
  }

  /// Leaving with unsaved changes asks first.
  Future<bool> _confirmLeave() =>
      confirmDiscardChanges(context, hasChanges: _hasUnsavedEdit);

  bool get _hasUnsavedEdit {
    final seeded = _seeded;

    return _editing && seeded != null && _differsFrom(seeded);
  }

  // Whitespace alone is not a change: values are compared as they would be
  // sent.
  bool _differsFrom(Scope scope) =>
      normalizeEmailLink(_verification.text) != scope.emailVerificationUrl ||
      normalizeEmailLink(_reset.text) != scope.passwordResetUrl;

  Future<void> _save() async {
    if (!validateAndReveal(_formKey)) {
      return; // AF-31e
    }

    await _controller.saveEmailLinks(
      emailVerificationUrl: _verification.text,
      passwordResetUrl: _reset.text,
    );
  }

  /// UI-15, moved here unchanged — including AF-15b's count-aware warning.
  Future<void> _toggleGoogleSignIn(bool enabled) async {
    if (!enabled) {
      final count = await ref
          .read(googleUserRepositoryProvider)
          .countIn(widget.scopeId);
      final present = count.valueOrNull;

      if (!mounted) {
        return;
      }

      if (present == null || present > 0) {
        final confirmed = await showConfirm(
          context: context,
          title: 'Turn Google Sign-In off?',
          message: present == null
              ? 'Any Google accounts already in this scope will no longer be '
                    'able to sign in.'
              : present == 1
              ? 'The 1 Google account already in this scope will no longer be '
                    'able to sign in.'
              : 'The $present Google accounts already in this scope will no '
                    'longer be able to sign in.',
          confirmLabel: 'Turn off',
        );

        if (!confirmed || !mounted) {
          return;
        }
      }
    }

    await _controller.setGoogleSignIn(enabled);
  }

  /// AF-31f and AF-31g — opening without a verification link, and closing,
  /// each ask first; a cancelled dialog sends nothing.
  Future<void> _toggleSelfRegistration(Scope scope, bool enabled) async {
    if (enabled && scope.emailVerificationUrl == null) {
      final confirmed = await showConfirm(
        context: context,
        title: 'Open self-registration?',
        message:
            "Sign-up confirmation emails will link to Heimdall's default "
            "page, not your application's. Open self-registration anyway?",
        confirmLabel: 'Open',
      );

      if (!confirmed || !mounted) {
        return;
      }
    }

    if (!enabled) {
      final confirmed = await showConfirm(
        context: context,
        title: 'Close self-registration?',
        message:
            'New sign-ups will be refused. People who have signed up but '
            'have not yet followed the link in their email will not be able '
            'to finish, and will need to sign up again once it reopens.',
        confirmLabel: 'Close',
      );

      if (!confirmed || !mounted) {
        return;
      }
    }

    await _controller.setSelfRegistration(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      scopeSignInSettingsControllerProvider(widget.scopeId),
    );

    // A save that went through ends the edit, as on the scope detail.
    ref.listen<SignInSettingsState>(
      scopeSignInSettingsControllerProvider(widget.scopeId),
      (previous, next) {
        if (previous is SignInSettingsLoaded &&
            previous.inFlight == SignInSettingsAction.emailLinks &&
            next is SignInSettingsLoaded &&
            next.linksSaved) {
          setState(() => _editing = false);
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      title: const Text('Sign-in & sign-up'),
      confirmLeave: _confirmLeave,
      body: switch (state) {
        SignInSettingsLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // AF-31a — the same panels the scope detail shows.
        SignInSettingsUnavailable(isNotFound: true) => CollectionEmpty(
          title: 'Scope not found',
          message:
              'There is no scope with that identifier. It may have been '
              'permanently deleted.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Back to scopes',
          onAction: () => context.go('/scopes'),
        ),
        SignInSettingsUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This scope is not one you administer. Nothing is wrong '
              'with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: 'Back to scopes',
          onAction: () => context.go('/scopes'),
        ),
        // AF-31h
        SignInSettingsUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: _controller.load,
        ),
        final SignInSettingsLoaded loaded => _settings(loaded),
      },
    );
  }

  Widget _settings(SignInSettingsLoaded state) {
    final theme = Theme.of(context);
    _seed(state.scope);
    final scope = state.scope;
    final locked = state.isBusy || state.isReadOnly;
    final editing = _editing && !state.isReadOnly;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // AF-31b — everything below is read-only because of it.
              if (state.isReadOnly) ...<Widget>[
                const _DeletedNotice(),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Ways in', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Google Sign-In'),
                        subtitle: Text(
                          scope.googleSignInEnabled
                              ? 'People may sign in to this scope with Google.'
                              : 'Google sign-in is off for this scope.',
                        ),
                        value: scope.googleSignInEnabled,
                        // AF-15c: disabled while a request is outstanding.
                        onChanged: locked ? null : _toggleGoogleSignIn,
                      ),
                      // AF-15a: the API's own strings, as returned.
                      if (state.googleSignInFailure
                          case final refusal?) ...<Widget>[
                        const SizedBox(height: 8),
                        ErrorBanner(failure: refusal),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Self-registration'),
                        subtitle: const Text(
                          'Lets people create their own account in this '
                          "scope from your application's sign-up screen. "
                          'Each one confirms by email before the account '
                          'exists.',
                        ),
                        value: scope.selfRegistrationEnabled,
                        onChanged: locked
                            ? null
                            : (enabled) =>
                                  _toggleSelfRegistration(scope, enabled),
                      ),
                      // AF-31c
                      if (state.selfRegistrationFailure
                          case final refusal?) ...<Widget>[
                        const SizedBox(height: 8),
                        ErrorBanner(failure: refusal),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (state.linksFailure
                        case final Failure failure) ...<Widget>[
                      // AF-31i: a transport failure can be tried again;
                      // AF-31d: a refusal carries the API's own strings.
                      if (failure.kind == FailureKind.network)
                        RetryBanner(
                          onRetry:
                              state.inFlight == SignInSettingsAction.emailLinks
                              ? null
                              : _save,
                        )
                      else
                        ErrorBanner(failure: failure),
                      const SizedBox(height: 16),
                    ],
                    if (state.linksSaved) ...<Widget>[
                      const _SavedNotice(),
                      const SizedBox(height: 16),
                    ],
                    EditableSection(
                      title: 'Email links',
                      editing: editing,
                      mayEdit: !state.isReadOnly,
                      saving: state.inFlight == SignInSettingsAction.emailLinks,
                      canSave: _differsFrom(scope) && !state.isBusy,
                      onEdit: _startEditing,
                      onCancel: _cancelEditing,
                      onSave: _save,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _verification,
                            readOnly: !editing,
                            maxLength: emailLinkMaxLength,
                            maxLengthEnforcement: MaxLengthEnforcement.none,
                            keyboardType: TextInputType.url,
                            decoration: recordFieldDecoration(
                              context,
                              label: 'Verification link',
                              editing: editing,
                              helperText:
                                  'Sign-up confirmation and email '
                                  "verification. Leave empty to use Heimdall's "
                                  'default.',
                            ).copyWith(helperMaxLines: 3),
                            validator: validateEmailLink,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _reset,
                            readOnly: !editing,
                            maxLength: emailLinkMaxLength,
                            maxLengthEnforcement: MaxLengthEnforcement.none,
                            keyboardType: TextInputType.url,
                            decoration: recordFieldDecoration(
                              context,
                              label: 'Password-reset link',
                              editing: editing,
                              helperText:
                                  "Password recovery. Leave empty to use Heimdall's "
                                  'default.',
                            ).copyWith(helperMaxLines: 3),
                            validator: validateEmailLink,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AF-31b — what a logically deleted scope says about its settings.
class _DeletedNotice extends StatelessWidget {
  const _DeletedNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This scope is deleted. Its settings are shown for reference '
              'and cannot be changed.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedNotice extends StatelessWidget {
  const _SavedNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Saved.',
        style: TextStyle(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
