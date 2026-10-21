import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/edit_mode.dart';
import '../../../shared/forms/field_rules.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/delete_actions.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../../shared/widgets/notice.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/scope.dart';
import 'scope_detail_controller.dart';
import 'scope_list_controller.dart';
import 'scope_sign_in_settings_screen.dart' show signInSettingsSummary;

/// UI-12 — one scope: what it is, who owns it, and what it contains.
class ScopeDetailScreen extends ConsumerStatefulWidget {
  const ScopeDetailScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<ScopeDetailScreen> createState() => _ScopeDetailScreenState();
}

class _ScopeDetailScreenState extends ConsumerState<ScopeDetailScreen> {
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  /// The record the fields were last seeded from, which is what AF-12e
  /// compares against to decide whether anything actually differs.
  Scope? _seeded;

  /// Whether the person has asked to change the record. The fields are
  /// read-only until they do, and again once the change is saved or dropped.
  bool _editing = false;

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
    _restore(scope);
  }

  void _restore(Scope scope) {
    _name.text = scope.name;
    _description.text = scope.description;
  }

  void _startEditing() {
    ref
        .read(scopeDetailControllerProvider(widget.scopeId).notifier)
        .acknowledgeSave();
    setState(() => _editing = true);
  }

  /// Leaving with unsaved changes — by the navigation, the back control or
  /// signing out — asks first.
  Future<bool> _confirmLeave() =>
      confirmDiscardChanges(context, hasChanges: _hasUnsavedEdit);

  bool get _hasUnsavedEdit {
    final seeded = _seeded;

    return _editing && seeded != null && _differsFrom(seeded);
  }

  /// Puts back what the API holds and leaves edit mode, dropping any refusal
  /// along with the edit it was about.
  void _cancelEditing() {
    ref
        .read(scopeDetailControllerProvider(widget.scopeId).notifier)
        .acknowledgeSave();
    setState(() {
      _editing = false;
      // A fresh key forgets the fields' validation messages too.
      _formKey = GlobalKey<FormState>();

      if (_seeded case final scope?) {
        _restore(scope);
      }
    });
  }

  bool _differsFrom(Scope scope) =>
      _name.text.trim() != scope.name ||
      _description.text.trim() != scope.description;

  /// AF-13e — only a System Admin deletes a scope.
  bool get _maySeeDeletion => _isSystemAdmin;

  /// Only a System Admin updates a scope's name and description: the API
  /// holds `PUT /api/scopes/{id}` to that role alone, so a Scope Admin is
  /// shown them read-only rather than offered a save it would refuse.
  bool get _mayUpdate => _isSystemAdmin;

  /// UC-49/UC-50: a System Admin, or a Scope Admin who owns this scope. The
  /// token's owned scopes say which; the API decides in the end.
  bool _mayManageRegistrations(Scope scope) {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated &&
        (session.principal.isSystemAdmin ||
            session.principal.ownedScopeIds.contains(scope.id));
  }

  bool get _isSystemAdmin {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.isSystemAdmin;
  }

  Future<void> _save() async {
    if (!validateAndReveal(_formKey)) {
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
        // A save that went through ends the edit.
        if (previous is ScopeDetailLoaded &&
            previous.saving &&
            next is ScopeDetailLoaded &&
            next.saved) {
          setState(() => _editing = false);
        }

        if (next is ScopeDeleted) {
          ref.read(scopeListControllerProvider.notifier).load();
          context.go('/scopes');
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      backRoute: '/scopes',
      backTooltip: 'Back to scopes',
      title: Text(switch (state) {
        ScopeDetailLoaded(:final scope) => scope.name,
        _ => 'Scope',
      }),
      confirmLeave: _confirmLeave,
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
    final mayEdit = !state.isReadOnly && _mayUpdate;
    final editing = _editing && mayEdit;

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
                const Notice(
                  'This scope is deleted. It is shown for reference and cannot be '
                  'changed from here.',
                  icon: Icons.delete_outline,
                  isError: true,
                ),
                const SizedBox(height: 16),
              ],
              _ScopeId(scopeId: scope.id),
              const SizedBox(height: 16),
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
                      const Notice('Saved.'),
                      const SizedBox(height: 16),
                    ],
                    EditableSection(
                      title: 'Details',
                      editing: editing,
                      mayEdit: mayEdit,
                      saving: state.saving,
                      // AF-12e: nothing to save is not an action.
                      canSave: _differsFrom(scope) && !state.deleting,
                      onEdit: _startEditing,
                      onCancel: _cancelEditing,
                      onSave: _save,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            maxLength: nameMaxLength,
                            controller: _name,
                            readOnly: !editing,
                            decoration: recordFieldDecoration(
                              context,
                              label: 'Name',
                              editing: editing,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Enter a name for the scope.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            maxLength: descriptionMaxLength,
                            controller: _description,
                            readOnly: !editing,
                            minLines: 2,
                            maxLines: 4,
                            decoration: recordFieldDecoration(
                              context,
                              label: 'Description',
                              editing: editing,
                            ),
                          ),
                        ],
                      ),
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
                      Text('Owners', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      // Identifiers mean nothing to a reader; the Owners
                      // screen linked below names each one.
                      Text(switch (scope.ownerCount) {
                        0 => 'No owners recorded.',
                        1 => '1 owner. Open Owners below to see who.',
                        final count =>
                          '$count owners. Open Owners below to see who.',
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('In this scope', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _Links(
                scope: scope,
                // A deleted scope has no registrations to manage: the API
                // answers 404 for them.
                showPendingRegistrations:
                    !state.isReadOnly && _mayManageRegistrations(scope),
              ),
              // AF-13e — a Scope Admin never sees either control. The API
              // refuses them either way; showing them would only promise
              // something that cannot happen.
              if (_maySeeDeletion && !state.isReadOnly) ...<Widget>[
                const SizedBox(height: 24),
                DeleteActions(
                  noun: 'scope',
                  confirmationValue: scope.name,
                  fieldLabel: 'Scope name',
                  permanentConsequence:
                      'The scope and everything in it — its persons, '
                      'applications, permissions, and Google users — are '
                      'erased.',
                  deleting: state.deleting || state.saving,
                  failure: state.deleteFailure,
                  onDelete: () => ref
                      .read(
                        scopeDetailControllerProvider(widget.scopeId).notifier,
                      )
                      .delete(),
                  onDeletePermanently: () => ref
                      .read(
                        scopeDetailControllerProvider(widget.scopeId).notifier,
                      )
                      .deletePermanently(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The scope's `PublicId`, which a calling application writes under
/// `heimdall.scopeId` before handing its users here to sign up or sign in.
/// Nowhere else in the interface shows it, so this is where it is copied from.
class _ScopeId extends StatelessWidget {
  const _ScopeId({required this.scopeId});

  final String scopeId;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: scopeId));
    messenger.showSnackBar(const SnackBar(content: Text('Scope ID copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Scope ID', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  SelectableText(
                    scopeId,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applications using this scope pass it to Heimdall to '
                    'create and authenticate their users.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy scope ID',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => _copy(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the scope's contents live. Each target arrives with its own use case;
/// until then the router says so rather than throwing.
class _Links extends StatelessWidget {
  const _Links({required this.scope, required this.showPendingRegistrations});

  final Scope scope;
  final bool showPendingRegistrations;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: <Widget>[
        for (final link
            in <({String label, IconData icon, String path, String? subtitle})>[
              (
                label: 'Owners',
                icon: Icons.shield_outlined,
                path: 'owners',
                subtitle: null,
              ),
              (
                label: 'Sign-in & sign-up',
                icon: Icons.login_outlined,
                path: 'sign-in-settings',
                subtitle: signInSettingsSummary(scope),
              ),
              (
                label: 'Persons',
                icon: Icons.people_outline,
                path: 'persons',
                subtitle: null,
              ),
              (
                label: 'Applications',
                icon: Icons.apps_outlined,
                path: 'applications',
                subtitle: null,
              ),
              if (showPendingRegistrations)
                (
                  label: 'Pending registrations',
                  icon: Icons.how_to_reg_outlined,
                  path: 'pending-registrations',
                  subtitle: null,
                ),
              (
                label: 'Permissions',
                icon: Icons.key_outlined,
                path: 'permissions',
                subtitle: null,
              ),
              (
                label: 'Google users',
                icon: Icons.account_circle_outlined,
                path: 'google-users',
                subtitle: null,
              ),
            ])
          ListTile(
            leading: Icon(link.icon),
            title: Text(link.label),
            subtitle: link.subtitle == null ? null : Text(link.subtitle!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/scopes/${scope.id}/${link.path}'),
          ),
      ],
    ),
  );
}
