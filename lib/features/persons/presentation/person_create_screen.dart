import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../home/presentation/home_screen.dart';
import 'person_create_controller.dart';

/// UI-17 — the create-person form.
class PersonCreateScreen extends ConsumerStatefulWidget {
  const PersonCreateScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<PersonCreateScreen> createState() => _PersonCreateScreenState();
}

class _PersonCreateScreenState extends ConsumerState<PersonCreateScreen> {
  @override
  void initState() {
    super.initState();
    // A refused or finished attempt from an earlier visit is not this one's:
    // the form starts clean every time it is opened.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.invalidate(personCreateControllerProvider(widget.scopeId)),
    );
  }

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Role _role = Role.user;
  bool _confirming = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Whether anything has been entered, which is what AF-17e asks about before
  /// letting the form go.
  bool get _isDirty =>
      _name.text.trim().isNotEmpty ||
      _email.text.trim().isNotEmpty ||
      _password.text.isNotEmpty ||
      _role != Role.user;

  Future<void> _submit() async {
    // AF-17a: an empty name, a malformed address, or an empty password never
    // reaches the API.
    if (!validateAndReveal(_formKey)) {
      return;
    }

    // A System Admin administers every scope, whichever scope this form was
    // opened from, so choosing it takes a deliberate second step.
    if (_role == Role.systemAdmin) {
      // One question at a time, and no answer to a screen that is gone.
      if (_confirming) {
        return;
      }

      _confirming = true;
      final bool confirmed;

      try {
        confirmed = await _confirmSystemAdmin();
      } finally {
        _confirming = false;
      }

      if (!confirmed || !mounted) {
        return;
      }
    }

    await ref
        .read(personCreateControllerProvider(widget.scopeId).notifier)
        .create(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
        );
  }

  Future<bool> _confirmSystemAdmin() => showConfirm(
    context: context,
    title: 'Create a System Admin?',
    message:
        'This person will be able to administer every scope, not only this '
        'one. Only continue if that is what you mean.',
    confirmLabel: 'Create System Admin',
    cancelLabel: 'Go back',
  );

  /// AF-17e — leaving a modified form asks first, whichever way it is left:
  /// Cancel, the back control, the navigation, or signing out.
  Future<bool> _confirmLeave() async =>
      !_isDirty ||
      await showConfirm(
        context: context,
        title: 'Discard this person?',
        message: 'What you have entered has not been saved and will be lost.',
        confirmLabel: 'Discard',
        destructive: true,
        cancelLabel: 'Keep editing',
      );

  Future<void> _cancel() async {
    if (await _confirmLeave() && mounted) {
      context.go('/scopes/${widget.scopeId}/persons');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(personCreateControllerProvider(widget.scopeId));
    final session = ref.watch(sessionControllerProvider);
    final sending = state is PersonCreateSending;

    // AF-17d: the roles this caller may create. A Scope Admin is offered only
    // the one they can actually make.
    final roles = session is Authenticated
        ? creatableRolesFor(session.principal)
        : const <Role>[Role.user];

    ref.listen<PersonCreateState>(
      personCreateControllerProvider(widget.scopeId),
      (previous, next) {
        if (next case PersonCreated(:final person)) {
          // The listing behind this form reads itself again once it is back
          // on top (`AppShell.onReturn`).
          context.go('/scopes/${widget.scopeId}/persons/${person.id}');
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('New person'),
      onBack: _cancel,
      confirmLeave: _confirmLeave,
      backTooltip: 'Back to the listing',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Create a person', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'The API sends them a verification email as soon as the '
                    'record exists.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (state is PersonCreateRejected) ...<Widget>[
                    if (state.failure.kind == FailureKind.network)
                      RetryBanner(onRetry: sending ? null : _submit)
                    else
                      // AF-17b, AF-17c, AF-17d: the API's own strings, as
                      // returned.
                      ErrorBanner(failure: state.failure),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    maxLength: nameMaxLength,
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Enter an email address.';
                      }

                      return isPlausibleEmail(email)
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => validateNewPassword(
                      value,
                      emptyMessage: 'Enter a password.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Role>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: <DropdownMenuItem<Role>>[
                      for (final role in roles)
                        DropdownMenuItem<Role>(
                          value: role,
                          child: Text(roleLabel(role)),
                        ),
                    ],
                    onChanged: sending
                        ? null
                        : (role) => setState(() => _role = role ?? Role.user),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _role == Role.user
                        ? 'A user belongs to this scope.'
                        : 'An administrator belongs to no scope.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: sending ? null : _submit,
                    child: sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create person'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: sending ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
