import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/delete_actions.dart';
import '../../../shared/widgets/notice.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import 'google_avatar.dart';
import 'google_user_detail_controller.dart';

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

    // A deleted Google user returns to the listing, which reads itself again.
    ref.listen<GoogleUserDetailState>(
      googleUserDetailControllerProvider(_ref),
      (previous, next) {
        if (next is GoogleUserDeleted) {
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
      backRoute: backToListing,
      backTooltip: 'Back to the listing',
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
                const Notice(
                  'This Google user is deleted. They are shown for reference.',
                  icon: Icons.person_off_outlined,
                  isError: true,
                ),
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
                DeleteActions(
                  recordName: user.name,
                  noun: 'Google user',
                  confirmationValue: user.email,
                  fieldLabel: 'Email address',
                  permanentConsequence: 'Their record is erased.',
                  anonymises: true,
                  // AF-29e: deleting is not a way to keep somebody out, and
                  // saying so is what stops it being used as one.
                  extraWarning:
                      'While this scope has Google Sign-In on, they can sign '
                      'in again and a new record will appear.',
                  deleting: state.deleting,
                  failure: state.deleteFailure,
                  // AF-29d: a Scope Admin never sees the permanent deletion.
                  mayDeletePermanently: _maySeeHardDelete,
                  onDelete: () => ref
                      .read(googleUserDetailControllerProvider(_ref).notifier)
                      .delete(),
                  onDeletePermanently: () => ref
                      .read(googleUserDetailControllerProvider(_ref).notifier)
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
