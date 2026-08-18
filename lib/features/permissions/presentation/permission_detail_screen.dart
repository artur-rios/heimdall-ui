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
import '../domain/scope_permission.dart';
import 'permission_detail_controller.dart';
import 'permission_list_controller.dart';

/// UI-26 — one scope permission.
class PermissionDetailScreen extends ConsumerStatefulWidget {
  const PermissionDetailScreen({
    required this.scopeId,
    required this.permissionId,
    super.key,
  });

  final String scopeId;
  final String permissionId;

  @override
  ConsumerState<PermissionDetailScreen> createState() =>
      _PermissionDetailScreenState();
}

class _PermissionDetailScreenState
    extends ConsumerState<PermissionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _includeAsJwtClaim = false;

  /// The record the fields were last seeded from, which is what AF-26e
  /// compares against.
  ScopePermission? _seeded;

  PermissionRef get _ref =>
      PermissionRef(scopeId: widget.scopeId, permissionId: widget.permissionId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(permissionDetailControllerProvider(_ref).notifier).load(),
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
  /// AF-26c is why this only runs when the record itself changed: a refused
  /// save must leave what the user entered exactly where it was.
  void _seed(ScopePermission permission) {
    if (identical(_seeded, permission)) {
      return;
    }

    _seeded = permission;
    _name.text = permission.name;
    _description.text = permission.description;
    _includeAsJwtClaim = permission.includeAsJwtClaim;
  }

  bool _differsFrom(ScopePermission permission) =>
      _name.text.trim() != permission.name ||
      _description.text.trim() != permission.description ||
      _includeAsJwtClaim != permission.includeAsJwtClaim;

  /// AF-27d — only a System Admin erases a permission permanently.
  bool get _maySeeHardDelete {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.isSystemAdmin;
  }

  /// AF-27a — a dialog the user closes sends nothing.
  Future<void> _confirmDelete(ScopePermission permission) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Delete ${permission.name}?',
      message:
          '${permission.name} will be marked deleted. The record is kept '
          'and the API can restore it.',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      await ref
          .read(permissionDetailControllerProvider(_ref).notifier)
          .delete();
    }
  }

  /// AF-27c — the confirm control stays disabled until the name matches.
  Future<void> _confirmDeletePermanently(ScopePermission permission) async {
    final confirmed = await showTypeToConfirm(
      context: context,
      title: 'Delete ${permission.name} permanently?',
      message:
          'The permission is erased. Tokens already issued that carry it '
          'keep doing so until they expire. This cannot be undone. Type its '
          'name to confirm:',
      confirmationValue: permission.name,
      fieldLabel: 'Permission name',
      confirmLabel: 'Delete permanently',
    );

    if (confirmed && mounted) {
      await ref
          .read(permissionDetailControllerProvider(_ref).notifier)
          .deletePermanently();
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(permissionDetailControllerProvider(_ref).notifier)
        .save(
          name: _name.text.trim(),
          description: _description.text.trim(),
          includeAsJwtClaim: _includeAsJwtClaim,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permissionDetailControllerProvider(_ref));
    final controller = ref.read(
      permissionDetailControllerProvider(_ref).notifier,
    );
    final backToListing = '/scopes/${widget.scopeId}/permissions';

    // A deleted permission returns to the listing, which is now stale.
    ref.listen<PermissionDetailState>(
      permissionDetailControllerProvider(_ref),
      (previous, next) {
        if (next is PermissionDeleted) {
          ref
              .read(permissionListControllerProvider(widget.scopeId).notifier)
              .load();
          context.go(backToListing);
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: Text(switch (state) {
        PermissionDetailLoaded(:final permission) => permission.name,
        _ => 'Permission',
      }),
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the listing',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(backToListing),
        ),
      ],
      body: switch (state) {
        PermissionDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // AF-26a — no such permission.
        PermissionDetailUnavailable(isNotFound: true) => CollectionEmpty(
          title: 'Permission not found',
          message:
              'There is no permission with that identifier. It may have '
              'been permanently deleted.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        // AF-26b — out of this role's reach.
        PermissionDetailUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This permission is not one you administer. Nothing is '
              'wrong with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        PermissionDetailUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: controller.load,
        ),
        // The listing is where a deleted permission leaves the user; this is
        // the frame in between.
        PermissionDeleted() => const Center(child: CircularProgressIndicator()),
        final PermissionDetailLoaded loaded => _detail(loaded),
      },
    );
  }

  Widget _detail(PermissionDetailLoaded state) {
    _seed(state.permission);
    final permission = state.permission;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // AF-26d — a deleted permission says so before anything else.
              if (state.isReadOnly) ...<Widget>[
                const _Notice(
                  icon: Icons.delete_outline,
                  message:
                      'This permission is deleted. It is shown for '
                      'reference and cannot be changed from here.',
                  destructive: true,
                ),
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
                        // AF-26c: the API's own strings, as returned.
                        ErrorBanner(failure: failure),
                      const SizedBox(height: 16),
                    ],
                    if (state.saved) ...<Widget>[
                      _Notice(
                        icon: Icons.check_circle_outline,
                        // AF-26e — the tokens already out there are unchanged,
                        // which is the part that is easy to assume otherwise.
                        message: state.claimChanged
                            ? (permission.includeAsJwtClaim
                                  ? 'Saved. Tokens this scope issues from now '
                                        'on carry this permission; tokens '
                                        'already issued do not.'
                                  : 'Saved. Tokens this scope issues from now '
                                        'on omit this permission; tokens '
                                        'already issued still carry it until '
                                        'they expire.')
                            : 'Saved.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _name,
                      readOnly: state.isReadOnly,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter a name for the permission.'
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
                    // FR-PM-04 — what the flag means, wherever it is shown.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include in tokens'),
                      subtitle: const Text(
                        'Every token this scope issues from now on carries '
                        'this permission as a claim. Tokens already issued are '
                        'unaffected until they expire.',
                      ),
                      value: _includeAsJwtClaim,
                      onChanged: (state.saving || state.isReadOnly)
                          ? null
                          : (value) =>
                                setState(() => _includeAsJwtClaim = value),
                    ),
                    const SizedBox(height: 16),
                    if (!state.isReadOnly)
                      FilledButton(
                        onPressed: (state.saving || !_differsFrom(permission))
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
              // AF-26d leaves a deleted permission nothing left to delete.
              if (!state.isReadOnly) ...<Widget>[
                const SizedBox(height: 24),
                _DangerZone(
                  permission: permission,
                  deleting: state.deleting,
                  failure: state.deleteFailure,
                  mayDeletePermanently: _maySeeHardDelete,
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

/// The two deletions, kept apart from the rest of the screen because neither
/// is an ordinary edit.
class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.permission,
    required this.deleting,
    required this.failure,
    required this.mayDeletePermanently,
    required this.onDelete,
    required this.onDeletePermanently,
  });

  final ScopePermission permission;
  final bool deleting;
  final Failure? failure;

  /// AF-27d — a Scope Admin never sees the permanent deletion.
  final bool mayDeletePermanently;

  final Future<void> Function(ScopePermission permission) onDelete;
  final Future<void> Function(ScopePermission permission) onDeletePermanently;

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
              'Delete this permission',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting keeps the record and can be undone by the API. '
              'Deleting permanently erases it.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            // AF-27b — the API refused, and the permission is still open.
            if (failure case final refusal?) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(failure: refusal),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: deleting ? null : () => onDelete(permission),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete permission'),
                ),
                if (mayDeletePermanently)
                  FilledButton.icon(
                    onPressed: deleting
                        ? null
                        : () => onDeletePermanently(permission),
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

/// A one-line panel: what a deleted record and a saved edit each say.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.destructive = false,
  });

  final IconData icon;
  final String message;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = destructive
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = destructive
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
