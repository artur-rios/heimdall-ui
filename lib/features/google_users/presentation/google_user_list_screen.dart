import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../scopes/presentation/scope_detail_controller.dart';
import '../domain/google_user.dart';
import 'google_avatar.dart';
import 'google_user_list_controller.dart';

/// UI-28 — the Google users of one scope.
class GoogleUserListScreen extends ConsumerStatefulWidget {
  const GoogleUserListScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<GoogleUserListScreen> createState() =>
      _GoogleUserListScreenState();
}

class _GoogleUserListScreenState extends ConsumerState<GoogleUserListScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(googleUserListControllerProvider(widget.scopeId).notifier)
          .load();
      // AF-28a needs to know whether the scope has Google Sign-In on, which is
      // the scope's own record rather than anything in this listing.
      ref.read(scopeDetailControllerProvider(widget.scopeId).notifier).load();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  GoogleUserListController get _controller =>
      ref.read(googleUserListControllerProvider(widget.scopeId).notifier);

  void _clearFilters() {
    _name.clear();
    _email.clear();
    _controller.clearFilters();
  }

  /// Whether the scope has Google Sign-In switched off, which is why nobody
  /// could have signed in. `null` while the scope is still being read.
  bool? get _googleSignInOff =>
      switch (ref.watch(scopeDetailControllerProvider(widget.scopeId))) {
        ScopeDetailLoaded(:final scope) => !scope.googleSignInEnabled,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(googleUserListControllerProvider(widget.scopeId));

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('Google users'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the scope',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scopes/${widget.scopeId}'),
        ),
      ],
      body: Column(
        children: <Widget>[
          _Filters(
            name: _name,
            email: _email,
            includeDeleted: state.query.includeDeleted,
            onSearch: () =>
                _controller.search(name: _name.text, email: _email.text),
            onIncludeDeletedChanged: _controller.setIncludeDeleted,
          ),
          Expanded(
            child: switch (state) {
              GoogleUserListLoading() => const CollectionLoading(),
              // AF-28c — the scope is not one this admin owns.
              GoogleUserListFailed(isForbidden: true) => CollectionEmpty(
                title: 'Not available for your role',
                message:
                    'This scope is not one you administer. Nothing is '
                    'wrong with your session.',
                icon: Icons.lock_person_outlined,
                actionLabel: 'Back to scopes',
                onAction: () => context.go('/scopes'),
              ),
              // AF-28b — the returned errors, with a retry.
              GoogleUserListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              GoogleUserListLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                _empty(query),
              final GoogleUserListLoaded loaded =>
                AdaptiveCollection<GoogleUser>(
                  items: loaded.page.items,
                  busy: loaded.busy,
                  pageNumber: loaded.page.pageNumber,
                  totalPages: loaded.page.totalPages,
                  totalItems: loaded.page.totalItems,
                  onPageChanged: _controller.goToPage,
                  onTap: (user) => context.go(
                    '/scopes/${widget.scopeId}/google-users/${user.id}',
                  ),
                  title: (user) => user.name,
                  subtitle: (user) => user.email,
                  columns: <CollectionColumn<GoogleUser>>[
                    CollectionColumn<GoogleUser>(
                      label: 'Picture',
                      // AF-28d: a missing or unreachable picture becomes
                      // initials; the row never breaks.
                      cell: (user) => GoogleAvatar(user: user, radius: 16),
                    ),
                    CollectionColumn<GoogleUser>(
                      label: 'Verified by Google',
                      cell: (user) => Text(user.emailVerified ? 'Yes' : 'No'),
                    ),
                    CollectionColumn<GoogleUser>(
                      label: 'State',
                      cell: (user) =>
                          Text(user.isDeleted ? 'Deleted' : 'Active'),
                    ),
                  ],
                ),
            },
          ),
        ],
      ),
    );
  }

  /// AF-28a — nobody has signed in with Google here, which is a different
  /// thing from a search that matched nothing. When the scope has the feature
  /// switched off, that is the reason, and UI-15 is where it is switched on.
  Widget _empty(GoogleUserQuery query) {
    if (query.isFiltered) {
      return CollectionEmpty(
        title: 'No Google users matched',
        message:
            'Nothing here matches what you searched for. Clearing the '
            'filters shows them all again.',
        icon: Icons.search_off_outlined,
        actionLabel: 'Clear filters',
        onAction: _clearFilters,
      );
    }

    final signInOff = _googleSignInOff;

    return CollectionEmpty(
      title: 'No Google users yet',
      message: signInOff ?? false
          ? 'A Google user appears here the first time somebody signs in to '
                'this scope with Google — and this scope has Google Sign-In '
                'switched off, so nobody can.'
          : 'A Google user appears here the first time somebody signs in to '
                'this scope with Google. Nobody has yet.',
      icon: Icons.account_circle_outlined,
      actionLabel: (signInOff ?? false) ? 'Scope settings' : null,
      onAction: (signInOff ?? false)
          ? () => context.go('/scopes/${widget.scopeId}')
          : null,
    );
  }
}

/// The two search fields and the include-deleted switch.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.name,
    required this.email,
    required this.includeDeleted,
    required this.onSearch,
    required this.onIncludeDeletedChanged,
  });

  final TextEditingController name;
  final TextEditingController email;
  final bool includeDeleted;
  final VoidCallback onSearch;
  final ValueChanged<bool> onIncludeDeletedChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    child: Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 260,
          child: TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Search by name',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            controller: email,
            decoration: const InputDecoration(
              labelText: 'Search by email',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        FilledButton.tonal(onPressed: onSearch, child: const Text('Search')),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Switch(value: includeDeleted, onChanged: onIncludeDeletedChanged),
            const SizedBox(width: 8),
            const Text('Include deleted'),
          ],
        ),
      ],
    ),
  );
}
