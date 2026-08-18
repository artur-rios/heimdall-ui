import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/google_user.dart';
import 'google_avatar.dart';
import 'google_user_detail_controller.dart';
import 'google_user_list_controller.dart';

/// UI-28 — one Google user, read-only.
///
/// AF-28e: every field comes from Google, so there is nothing here to edit.
class GoogleUserDetailScreen extends ConsumerStatefulWidget {
  const GoogleUserDetailScreen({
    required this.scopeId,
    required this.googleUserId,
    super.key,
  });

  final String scopeId;
  final String googleUserId;

  @override
  ConsumerState<GoogleUserDetailScreen> createState() =>
      _GoogleUserDetailScreenState();
}

class _GoogleUserDetailScreenState
    extends ConsumerState<GoogleUserDetailScreen> {
  GoogleUserRef get _ref =>
      GoogleUserRef(scopeId: widget.scopeId, googleUserId: widget.googleUserId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(googleUserDetailControllerProvider(_ref).notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(googleUserDetailControllerProvider(_ref));
    final controller = ref.read(
      googleUserDetailControllerProvider(_ref).notifier,
    );
    final backToListing = '/scopes/${widget.scopeId}/google-users';

    // A deleted Google user returns to the listing, which is now stale.
    ref.listen<GoogleUserDetailState>(
      googleUserDetailControllerProvider(_ref),
      (previous, next) {
        if (next is GoogleUserDeleted) {
          ref
              .read(googleUserListControllerProvider(widget.scopeId).notifier)
              .load();
          context.go(backToListing);
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      title: Text(switch (state) {
        GoogleUserDetailLoaded(:final user) => user.name,
        _ => 'Google user',
      }),
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the listing',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(backToListing),
        ),
      ],
      body: switch (state) {
        GoogleUserDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        GoogleUserDetailUnavailable(isNotFound: true) => CollectionEmpty(
          title: 'Google user not found',
          message:
              'There is no Google user with that identifier. They may '
              'have been permanently deleted.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        GoogleUserDetailUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This Google user is not one you administer. Nothing is '
              'wrong with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: 'Back to the listing',
          onAction: () => context.go(backToListing),
        ),
        GoogleUserDetailUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: controller.load,
        ),
        // The listing is where a deleted record leaves the user; this is the
        // frame in between.
        GoogleUserDeleted() => const Center(child: CircularProgressIndicator()),
        final GoogleUserDetailLoaded loaded => _detail(loaded),
      },
    );
  }

  /// AF-29d — only a System Admin erases a Google user permanently.
  bool get _maySeeHardDelete {
    final session = ref.watch(sessionControllerProvider);

    return session is Authenticated && session.principal.isSystemAdmin;
  }

  /// AF-29a — a dialog the user closes sends nothing.
  ///
  /// AF-29e: deleting the record does not stop the person signing in again,
  /// which the message says rather than letting it be assumed otherwise.
  Future<void> _confirmDelete(GoogleUser user) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Delete ${user.name}?',
      message:
          '${user.name} will be marked deleted. The record is kept and '
          'the API can restore it. While this scope has Google Sign-In on, '
          'they can sign in again and a new record will appear.',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      await ref
          .read(googleUserDetailControllerProvider(_ref).notifier)
          .delete();
    }
  }

  /// AF-29c — the confirm control stays disabled until the address matches.
  Future<void> _confirmDeletePermanently(GoogleUser user) async {
    final confirmed = await showTypeToConfirm(
      context: context,
      title: 'Delete ${user.name} permanently?',
      message:
          'Their record is erased. This cannot be undone — though while '
          'this scope has Google Sign-In on, they can sign in again and a new '
          'record will appear. Type their email address to confirm:',
      confirmationValue: user.email,
      fieldLabel: 'Email address',
      confirmLabel: 'Delete permanently',
    );

    if (confirmed && mounted) {
      await ref
          .read(googleUserDetailControllerProvider(_ref).notifier)
          .deletePermanently();
    }
  }

  Widget _detail(GoogleUserDetailLoaded state) {
    final theme = Theme.of(context);
    final user = state.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (user.isDeleted) ...<Widget>[
                _DeletedNotice(),
                const SizedBox(height: 16),
              ],
              Row(
                children: <Widget>[
                  // AF-28d: the picture, or the initials when there is none.
                  GoogleAvatar(user: user, radius: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(user.name, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(user.email, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // AF-28e — read-only, and it says why rather than leaving the
              // absence of controls to be puzzled over.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'These details come from Google and cannot be '
                          'changed here.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        _Fact(label: 'Identifier', value: user.id),
                        _Fact(
                          label: 'Google identifier',
                          value: user.googleId ?? 'Not reported',
                        ),
                        _Fact(
                          label: 'Verified by Google',
                          value: user.emailVerified ? 'Yes' : 'No',
                        ),
                        _Fact(
                          label: 'Scope',
                          value: user.scopeId ?? widget.scopeId,
                        ),
                        _Fact(
                          label: 'State',
                          value: user.isDeleted ? 'Deleted' : 'Active',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // A deleted record has nothing left to delete.
              if (!user.isDeleted) ...<Widget>[
                const SizedBox(height: 24),
                _DangerZone(
                  user: user,
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
    required this.user,
    required this.deleting,
    required this.failure,
    required this.mayDeletePermanently,
    required this.onDelete,
    required this.onDeletePermanently,
  });

  final GoogleUser user;
  final bool deleting;
  final Failure? failure;

  /// AF-29d — a Scope Admin never sees the permanent deletion.
  final bool mayDeletePermanently;

  final Future<void> Function(GoogleUser user) onDelete;
  final Future<void> Function(GoogleUser user) onDeletePermanently;

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
              'Delete this Google user',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            // AF-29e — deleting is not a way to keep somebody out, and saying
            // so here is what stops it being used as one.
            Text(
              'Deleting keeps the record and can be undone by the API; '
              'deleting permanently erases it. Neither stops them signing in '
              'again while this scope has Google Sign-In on.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            // AF-29b — the API refused, and the record is still open.
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
                  onPressed: deleting ? null : () => onDelete(user),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Google user'),
                ),
                if (mayDeletePermanently)
                  FilledButton.icon(
                    onPressed: deleting
                        ? null
                        : () => onDeletePermanently(user),
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

class _DeletedNotice extends StatelessWidget {
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
          Icon(Icons.person_off_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This Google user is deleted. They are shown for reference.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 160,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
