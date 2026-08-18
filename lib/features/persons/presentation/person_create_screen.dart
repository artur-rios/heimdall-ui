import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../home/presentation/home_screen.dart';
import 'person_create_controller.dart';
import 'person_list_controller.dart';

/// UI-17 — the create-person form.
class PersonCreateScreen extends ConsumerStatefulWidget {
  const PersonCreateScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<PersonCreateScreen> createState() => _PersonCreateScreenState();
}

class _PersonCreateScreenState extends ConsumerState<PersonCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Role _role = Role.user;

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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
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

  /// AF-17e — leaving a modified form asks first.
  Future<void> _cancel() async {
    final leave =
        !_isDirty ||
        await showConfirm(
          context: context,
          title: 'Discard this person?',
          message: 'What you have entered has not been saved and will be lost.',
          confirmLabel: 'Discard',
          cancelLabel: 'Keep editing',
        );

    if (leave && mounted) {
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
          // The listing behind this form is now stale.
          ref
              .read(personListControllerProvider(widget.scopeId).notifier)
              .load();
          context.go('/scopes/${widget.scopeId}/persons/${person.id}');
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('New person'),
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

                      return email.contains('@')
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'Enter a password.' : null,
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
