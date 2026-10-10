import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../../persons/domain/person.dart';
import '../../persons/presentation/scope_admin_picker.dart';
import 'scope_create_controller.dart';
import 'scope_list_controller.dart';

/// UI-11 — the create-scope form.
///
/// Owners are chosen from the administrators the API lists — Scope Admins, and
/// for a System Admin the System Admins too — or a System Admin adds
/// themselves, which is what makes a first scope possible before any Scope
/// Admin exists. Whether each one is still usable by the time the scope is
/// created remains the API's to say, so AF-11c is still what its refusal looks
/// like.
class ScopeCreateScreen extends ConsumerStatefulWidget {
  const ScopeCreateScreen({super.key});

  @override
  ConsumerState<ScopeCreateScreen> createState() => _ScopeCreateScreenState();
}

class _ScopeCreateScreenState extends ConsumerState<ScopeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final List<PersonSummary> _owners = <PersonSummary>[];

  /// The owner list as a form field, so AF-11a's "at least one owner" is
  /// refused on screen the way an empty name is, instead of not at all.
  final _ownersField = GlobalKey<FormFieldState<List<PersonSummary>>>();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Whether anything has been entered, which is what AF-11d asks about before
  /// letting the form go.
  bool get _isDirty =>
      _name.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty ||
      _owners.isNotEmpty;

  /// The scope does not exist yet, so there are no owners for the API to leave
  /// out — only the ones already chosen here, which it cannot know about.
  Future<void> _addOwner() async {
    final chosen = await showScopeAdminPicker(
      context: context,
      excludeIds: _owners.map((owner) => owner.id).toSet(),
    );

    if (chosen != null && mounted) {
      _changeOwners(() => _owners.add(chosen));
    }
  }

  /// The signed-in person as an owner, when they are a System Admin — the
  /// only administrator who can be creating a scope.
  PersonSummary? get _me {
    final session = ref.watch(sessionControllerProvider);

    if (session is! Authenticated || !session.principal.isSystemAdmin) {
      return null;
    }

    final principal = session.principal;

    return PersonSummary(
      id: principal.id,
      name: principal.displayName,
      email: principal.email,
    );
  }

  /// Applies [change] to the owner list, and lets an "owner required" error
  /// already on screen go as soon as it no longer applies.
  void _changeOwners(VoidCallback change) {
    setState(change);

    if (_ownersField.currentState?.hasError ?? false) {
      _ownersField.currentState?.validate();
    }
  }

  Future<void> _submit() async {
    // AF-11a: an empty name, or a scope with nobody to own it, never reaches
    // the API — and the form says which.
    if (!validateAndReveal(_formKey)) {
      return;
    }

    await ref
        .read(scopeCreateControllerProvider.notifier)
        .create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          ownerIds: _owners.map((owner) => owner.id).toList(growable: false),
        );
  }

  /// AF-11d — leaving a modified form asks first.
  Future<bool> _confirmLeave() async {
    if (!_isDirty) {
      return true;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this scope?'),
        content: const Text(
          'What you have entered has not been saved and will be lost.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return leave ?? false;
  }

  Future<void> _cancel() async {
    if (await _confirmLeave() && mounted) {
      context.go('/scopes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(scopeCreateControllerProvider);
    final sending = state is ScopeCreateSending;
    final me = _me;

    // The new scope's detail is where the flow ends. Listening rather than
    // reacting in the build keeps the navigation out of a widget build.
    ref.listen<ScopeCreateState>(scopeCreateControllerProvider, (
      previous,
      next,
    ) {
      if (next case ScopeCreated(:final scope)) {
        // The listing behind this form is now stale.
        ref.read(scopeListControllerProvider.notifier).load();
        context.go('/scopes/${scope.id}');
      }
    });

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('New scope'),
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
                  Text('Create a scope', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'A scope is one tenant. It needs a name and at least one '
                    'owner — a Scope Admin, or you.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (state is ScopeCreateRejected) ...<Widget>[
                    if (state.failure.kind == FailureKind.network)
                      // AF-11e: nothing was created, so the same submission is
                      // worth making again against what is still on screen.
                      RetryBanner(onRetry: sending ? null : _submit)
                    else
                      // AF-11b and AF-11c: the API's own strings, as returned.
                      ErrorBanner(failure: state.failure),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    maxLength: nameMaxLength,
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a name for the scope.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    maxLength: descriptionMaxLength,
                    controller: _description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 24),
                  Text('Owners', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: sending ? null : _addOwner,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Add owner'),
                      ),
                      if (me != null &&
                          !_owners.any((owner) => owner.id == me.id))
                        OutlinedButton.icon(
                          onPressed: sending
                              ? null
                              : () => _changeOwners(() => _owners.add(me)),
                          icon: const Icon(Icons.how_to_reg_outlined),
                          label: const Text('Add me'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FormField<List<PersonSummary>>(
                    key: _ownersField,
                    validator: (_) => _owners.isEmpty
                        ? 'Add at least one owner — a Scope Admin, or '
                              'yourself.'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (_owners.isEmpty)
                          Text(
                            'No owners added yet.',
                            style: theme.textTheme.bodySmall,
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final owner in _owners)
                                InputChip(
                                  label: Text(owner.name),
                                  deleteIcon: const Icon(Icons.close),
                                  deleteButtonTooltipMessage: 'Remove owner',
                                  onDeleted: sending
                                      ? null
                                      : () => _changeOwners(
                                          () => _owners.remove(owner),
                                        ),
                                ),
                            ],
                          ),
                        if (field.errorText case final error?) ...<Widget>[
                          const SizedBox(height: 8),
                          FormRequirementError(error),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: sending ? null : _submit,
                    child: sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create scope'),
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
