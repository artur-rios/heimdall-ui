import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/failure_banner.dart';
import 'scope_create_controller.dart';
import 'scope_list_controller.dart';

/// UI-11 — the create-scope form.
///
/// Owners are named by their person identifier. The API has no endpoint that
/// lists the Scope Admins an anonymous new scope could choose from, so the
/// identifiers are typed and the API judges them (AF-11c).
class ScopeCreateScreen extends ConsumerStatefulWidget {
  const ScopeCreateScreen({super.key});

  @override
  ConsumerState<ScopeCreateScreen> createState() => _ScopeCreateScreenState();
}

class _ScopeCreateScreenState extends ConsumerState<ScopeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _owner = TextEditingController();
  final List<String> _ownerIds = <String>[];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _owner.dispose();
    super.dispose();
  }

  /// Whether anything has been entered, which is what AF-11d asks about before
  /// letting the form go.
  bool get _isDirty =>
      _name.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty ||
      _owner.text.trim().isNotEmpty ||
      _ownerIds.isNotEmpty;

  void _addOwner() {
    final id = _owner.text.trim();

    if (id.isEmpty || _ownerIds.contains(id)) {
      return;
    }

    setState(() {
      _ownerIds.add(id);
      _owner.clear();
    });
  }

  Future<void> _submit() async {
    // AF-11a: an empty name never reaches the API.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // AF-11a: neither does a scope with nobody to own it. The unadded text in
    // the owner field counts, so a user who typed one and did not press add is
    // not told they forgot.
    _addOwner();

    if (_ownerIds.isEmpty) {
      setState(() {});

      return;
    }

    await ref
        .read(scopeCreateControllerProvider.notifier)
        .create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          ownerIds: List<String>.unmodifiable(_ownerIds),
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
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _owner,
                          decoration: const InputDecoration(
                            labelText: 'Scope Admin identifier',
                            helperText:
                                'The person id of an existing Scope '
                                'Admin.',
                          ),
                          onSubmitted: (_) => _addOwner(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Add owner',
                        icon: const Icon(Icons.add),
                        onPressed: sending ? null : _addOwner,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_ownerIds.isEmpty)
                    Text(
                      'No owners added yet.',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final id in _ownerIds)
                          InputChip(
                            label: Text(id),
                            deleteIcon: const Icon(Icons.close),
                            deleteButtonTooltipMessage: 'Remove owner',
                            onDeleted: sending
                                ? null
                                : () => setState(() => _ownerIds.remove(id)),
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
