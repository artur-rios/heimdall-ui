import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/scope_permission.dart';
import 'permission_detail_controller.dart';

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
            ],
          ),
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
