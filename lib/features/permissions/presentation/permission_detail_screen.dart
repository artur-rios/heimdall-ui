import 'package:flutter/material.dart';
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
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _includeAsJwtClaim = false;

  /// The record the fields were last seeded from, which is what AF-26e
  /// compares against.
  ScopePermission? _seeded;

  /// Whether the person has asked to change the record. The fields are
  /// read-only until they do, and again once the change is saved or dropped.
  bool _editing = false;

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
    _restore(permission);
  }

  void _restore(ScopePermission permission) {
    _name.text = permission.name;
    _description.text = permission.description;
    _includeAsJwtClaim = permission.includeAsJwtClaim;
  }

  void _startEditing() {
    ref
        .read(permissionDetailControllerProvider(_ref).notifier)
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
        .read(permissionDetailControllerProvider(_ref).notifier)
        .acknowledgeSave();
    setState(() {
      _editing = false;
      // A fresh key forgets the fields' validation messages too.
      _formKey = GlobalKey<FormState>();

      if (_seeded case final permission?) {
        _restore(permission);
      }
    });
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

  Future<void> _save() async {
    if (!validateAndReveal(_formKey)) {
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
        // A save that went through ends the edit.
        if (previous is PermissionDetailLoaded &&
            previous.saving &&
            next is PermissionDetailLoaded &&
            next.saved) {
          setState(() => _editing = false);
        }

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
      confirmLeave: _confirmLeave,
      backRoute: backToListing,
      backTooltip: 'Back to the listing',
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
    final editing = _editing && !state.isReadOnly;

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
                const Notice(
                  'This permission is deleted. It is shown for '
                  'reference and cannot be changed from here.',
                  icon: Icons.delete_outline,
                  isError: true,
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
                      Notice(
                        state.claimChanged
                            ? (permission.includeAsJwtClaim
                                  ? 'Saved. Tokens this scope issues from now '
                                        'on carry this permission; tokens '
                                        'already issued do not.'
                                  : 'Saved. Tokens this scope issues from now '
                                        'on omit this permission; tokens '
                                        'already issued still carry it until '
                                        'they expire.')
                            : 'Saved.',
                        icon: Icons.check_circle_outline,
                      ),
                      const SizedBox(height: 16),
                    ],
                    EditableSection(
                      title: 'Details',
                      editing: editing,
                      mayEdit: !state.isReadOnly,
                      saving: state.saving,
                      canSave: _differsFrom(permission) && !state.deleting,
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
                                ? 'Enter a name for the permission.'
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
                          const SizedBox(height: 8),
                          // FR-PM-04 — what the flag means, wherever it is
                          // shown.
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Include in tokens'),
                            subtitle: const Text(
                              'Every token this scope issues from now on '
                              'carries this permission as a claim. Tokens '
                              'already issued are unaffected until they '
                              'expire.',
                            ),
                            value: _includeAsJwtClaim,
                            onChanged: (state.saving || !editing)
                                ? null
                                : (value) => setState(
                                    () => _includeAsJwtClaim = value,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // AF-26d leaves a deleted permission nothing left to delete.
              if (!state.isReadOnly) ...<Widget>[
                const SizedBox(height: 24),
                DeleteActions(
                  recordName: permission.name,
                  noun: 'permission',
                  confirmationValue: permission.name,
                  fieldLabel: 'Permission name',
                  permanentConsequence:
                      'The permission is erased. Tokens already issued that '
                      'carry it keep doing so until they expire.',
                  deleting: state.deleting || state.saving,
                  failure: state.deleteFailure,
                  // AF-27d: a Scope Admin never sees the permanent deletion.
                  mayDeletePermanently: _maySeeHardDelete,
                  onDelete: () => ref
                      .read(permissionDetailControllerProvider(_ref).notifier)
                      .delete(),
                  onDeletePermanently: () => ref
                      .read(permissionDetailControllerProvider(_ref).notifier)
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
