import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import 'permission_create_controller.dart';
import 'permission_list_controller.dart';

/// UI-25 — the create-permission form.
class PermissionCreateScreen extends ConsumerStatefulWidget {
  const PermissionCreateScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<PermissionCreateScreen> createState() =>
      _PermissionCreateScreenState();
}

class _PermissionCreateScreenState
    extends ConsumerState<PermissionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _includeAsJwtClaim = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Whether anything has been entered, which is what AF-25c asks about.
  bool get _isDirty =>
      _name.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty ||
      _includeAsJwtClaim;

  Future<void> _submit() async {
    // AF-25a: an empty name never reaches the API.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(permissionCreateControllerProvider(widget.scopeId).notifier)
        .create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          includeAsJwtClaim: _includeAsJwtClaim,
        );
  }

  /// AF-25c — leaving a modified form asks first.
  Future<void> _cancel() async {
    final leave =
        !_isDirty ||
        await showConfirm(
          context: context,
          title: 'Discard this permission?',
          message: 'What you have entered has not been saved and will be lost.',
          confirmLabel: 'Discard',
          cancelLabel: 'Keep editing',
        );

    if (leave && mounted) {
      context.go('/scopes/${widget.scopeId}/permissions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(permissionCreateControllerProvider(widget.scopeId));
    final sending = state is PermissionCreateSending;

    ref.listen<PermissionCreateState>(
      permissionCreateControllerProvider(widget.scopeId),
      (previous, next) {
        if (next case PermissionCreated(:final permission)) {
          // The listing behind this form is now stale.
          ref
              .read(permissionListControllerProvider(widget.scopeId).notifier)
              .load();
          context.go('/scopes/${widget.scopeId}/permissions/${permission.id}');
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('New permission'),
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
                  Text(
                    'Create a permission',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A permission is something this scope’s applications can '
                    'check for.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (state is PermissionCreateRejected) ...<Widget>[
                    if (state.failure.kind == FailureKind.network)
                      RetryBanner(onRetry: sending ? null : _submit)
                    else
                      // AF-25b: the API's own strings, as returned.
                      ErrorBanner(failure: state.failure),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a name for the permission.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  // AF-25d and FR-PM-04 — what setting this actually does is
                  // said here, not left to be discovered in a token.
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include in tokens'),
                    subtitle: const Text(
                      'Every token this scope issues from now on carries this '
                      'permission as a claim, so its applications can read it '
                      'without asking the API again.',
                    ),
                    value: _includeAsJwtClaim,
                    onChanged: sending
                        ? null
                        : (value) => setState(() => _includeAsJwtClaim = value),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: sending ? null : _submit,
                    child: sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create permission'),
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
