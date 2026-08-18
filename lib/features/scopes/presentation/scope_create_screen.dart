import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../persons/domain/person.dart';
import '../../persons/presentation/scope_admin_picker.dart';
import 'scope_create_controller.dart';
import 'scope_list_controller.dart';

/// UI-11 — the create-scope form.
///
/// Owners are chosen from the Scope Admins the API lists. Whether each one is
/// still usable by the time the scope is created remains the API's to say, so
/// AF-11c is still what its refusal looks like.
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
      setState(() => _owners.add(chosen));
    }
  }

  Future<void> _submit() async {
    // AF-11a: an empty name never reaches the API.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // AF-11a: neither does a scope with nobody to own it.
    if (_owners.isEmpty) {
      setState(() {});

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
                    'Scope Admin to own it.',
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
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a name for the scope.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 24),
                  Text('Owners', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: sending ? null : _addOwner,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Add owner'),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                                : () => setState(() => _owners.remove(owner)),
                          ),
                      ],
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
