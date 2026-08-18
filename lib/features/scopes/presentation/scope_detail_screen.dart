import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/scope.dart';
import 'scope_detail_controller.dart';
import 'scope_list_controller.dart';

/// UI-12 — one scope: what it is, who owns it, and what it contains.
class ScopeDetailScreen extends ConsumerStatefulWidget {
  const ScopeDetailScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<ScopeDetailScreen> createState() => _ScopeDetailScreenState();
}

class _ScopeDetailScreenState extends ConsumerState<ScopeDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  /// The record the fields were last seeded from, which is what AF-12e
  /// compares against to decide whether anything actually differs.
  Scope? _seeded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(scopeDetailControllerProvider(widget.scopeId).notifier)
          .load(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Copies a freshly read or freshly saved record into the fields.
  ///
  /// AF-12c is why this only runs when the record itself changed: a refused
  /// save must leave what the user typed exactly where it was.
  void _seed(Scope scope) {
    if (identical(_seeded, scope)) {
      return;
    }

    _seeded = scope;
    _name.text = scope.name;
    _description.text = scope.description;
  }

  bool _differsFrom(Scope scope) =>
      _name.text.trim() != scope.name ||
      _description.text.trim() != scope.description;

  /// AF-13e — only a System Admin deletes a scope.
  bool get _maySeeDeletion {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.isSystemAdmin;
  }

  /// AF-13a — a dialog the user closes sends nothing.
  Future<void> _confirmDelete(Scope scope) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Delete this scope?',
      message:
          '${scope.name} will be marked deleted. The record is kept and '
          'the API can restore it.',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      await ref
          .read(scopeDetailControllerProvider(widget.scopeId).notifier)
          .delete();
    }
  }

  /// AF-13c — the confirm control stays disabled until the name matches.
  Future<void> _confirmDeletePermanently(Scope scope) async {
    final confirmed = await showTypeToConfirm(
      context: context,
      title: 'Delete this scope permanently?',
      message:
          'The scope and everything in it — its persons, applications, '
          'permissions, and Google users — are erased. This cannot be undone. '
          'Type the name to confirm:',
      confirmationValue: scope.name,
      fieldLabel: 'Scope name',
      confirmLabel: 'Delete permanently',
    );

    if (confirmed && mounted) {
      await ref
          .read(scopeDetailControllerProvider(widget.scopeId).notifier)
          .deletePermanently();
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(scopeDetailControllerProvider(widget.scopeId).notifier)
        .save(name: _name.text.trim(), description: _description.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scopeDetailControllerProvider(widget.scopeId));
    final controller = ref.read(
      scopeDetailControllerProvider(widget.scopeId).notifier,
    );

    // A deleted scope returns to the listing, which is now stale.
    ref.listen<ScopeDetailState>(
      scopeDetailControllerProvider(widget.scopeId),
      (previous, next) {
        if (next is ScopeDeleted) {
          ref.read(scopeListControllerProvider.notifier).load();
          context.go('/scopes');
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: Text(switch (state) {
        ScopeDetailLoaded(:final scope) => scope.name,
        _ => 'Scope',
      }),
      body: switch (state) {
        ScopeDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // AF-12a — no such scope.
        ScopeDetailUnavailable(isNotFound: true) => CollectionEmpty(
          title: 'Scope not found',
          message:
              'There is no scope with that identifier. It may have been '
              'permanently deleted.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Back to scopes',
          onAction: () => context.go('/scopes'),
        ),
        // AF-12b — the API says this scope is not this caller's, which is the
        // same answer UI-07 gives for a screen a role is not offered.
        ScopeDetailUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This scope is not one you administer. Nothing is wrong '
              'with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: 'Back to scopes',
          onAction: () => context.go('/scopes'),
        ),
        ScopeDetailUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: controller.load,
        ),
        // The listing is where a deleted scope leaves the user; this is the
        // frame in between.
        ScopeDeleted() => const Center(child: CircularProgressIndicator()),
        final ScopeDetailLoaded loaded => _detail(loaded),
      },
    );
  }

  Widget _detail(ScopeDetailLoaded state) {
    final theme = Theme.of(context);
    _seed(state.scope);
    final scope = state.scope;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // AF-12d — a deleted scope says so before anything else, since
              // everything below it is read-only because of it.
              if (state.isReadOnly) ...<Widget>[
                const _DeletedNotice(),
                const SizedBox(height: 16),
              ],
              Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (state.saveFailure
                        case final Failure failure) ...<Widget>[
                      if (failure.kind == FailureKind.network)
                        RetryBanner(onRetry: state.saving ? null : _save)
                      else
                        // AF-12c: the API's own strings, as returned.
                        ErrorBanner(failure: failure),
                      const SizedBox(height: 16),
                    ],
                    if (state.saved) ...<Widget>[
                      const _SavedNotice(),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _name,
                      readOnly: state.isReadOnly,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter a name for the scope.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      readOnly: state.isReadOnly,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!state.isReadOnly)
                      FilledButton(
                        // AF-12e: nothing to save is not an action.
                        onPressed: (state.saving || !_differsFrom(scope))
                            ? null
                            : _save,
                        child: state.saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save changes'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Google Sign-In', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(scope.googleSignInEnabled ? 'On' : 'Off'),
                      const SizedBox(height: 16),
                      Text('Owners', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        scope.ownerIds.isEmpty
                            ? 'No owners recorded.'
                            : scope.ownerIds.join(', '),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('In this scope', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _Links(scopeId: scope.id),
              // AF-13e — a Scope Admin never sees either control. The API
              // refuses them either way; showing them would only promise
              // something that cannot happen.
              if (_maySeeDeletion && !state.isReadOnly) ...<Widget>[
                const SizedBox(height: 24),
                _DangerZone(
                  scope: scope,
                  deleting: state.deleting,
                  failure: state.deleteFailure,
                  onDelete: _confirmDelete,
                  onDeletePermanently: _confirmDeletePermanently,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the scope's contents live. Each target arrives with its own use case;
/// until then the router says so rather than throwing.
class _Links extends StatelessWidget {
  const _Links({required this.scopeId});

  final String scopeId;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: <Widget>[
        for (final link in <({String label, IconData icon, String path})>[
          (label: 'Owners', icon: Icons.shield_outlined, path: 'owners'),
          (label: 'Persons', icon: Icons.people_outline, path: 'persons'),
          (
            label: 'Applications',
            icon: Icons.apps_outlined,
            path: 'applications',
          ),
          (label: 'Permissions', icon: Icons.key_outlined, path: 'permissions'),
          (
            label: 'Google users',
            icon: Icons.account_circle_outlined,
            path: 'google-users',
          ),
        ])
          ListTile(
            leading: Icon(link.icon),
            title: Text(link.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/scopes/$scopeId/${link.path}'),
          ),
      ],
    ),
  );
}

/// AF-12d — what a logically deleted scope says about itself.
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
              'This scope is deleted. It is shown for reference and cannot be '
              'changed from here.',
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

/// The two deletions, kept apart from everything else on the screen because
/// neither is an ordinary edit.
class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.scope,
    required this.deleting,
    required this.failure,
    required this.onDelete,
    required this.onDeletePermanently,
  });

  final Scope scope;
  final bool deleting;
  final Failure? failure;
  final Future<void> Function(Scope scope) onDelete;
  final Future<void> Function(Scope scope) onDeletePermanently;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Delete this scope',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting keeps the record and can be undone by the API. '
              'Deleting permanently erases the scope and everything in it.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            // AF-13b — the API refused, and the scope is still open.
            if (failure case final Failure refusal) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(failure: refusal),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: deleting ? null : () => onDelete(scope),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete scope'),
                ),
                FilledButton.icon(
                  onPressed: deleting ? null : () => onDeletePermanently(scope),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete permanently'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
