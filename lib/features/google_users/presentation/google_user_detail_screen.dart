import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../domain/google_user.dart';
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
        GoogleUserDetailLoaded(:final user) => _detail(user),
      },
    );
  }

  Widget _detail(GoogleUser user) {
    final theme = Theme.of(context);

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
            ],
          ),
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
