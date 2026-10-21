import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/list_filters.dart';
import '../../../shared/widgets/list_scaffold.dart';
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
    // The listing remembers its filters between visits, so the fields say
    // what it is still filtered by rather than starting blank.
    final query = ref
        .read(googleUserListControllerProvider(widget.scopeId))
        .query;
    _name.text = query.name;
    _email.text = query.email;
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
      // Back from a record that may have been changed or deleted.
      onReturn: _controller.load,
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      body: Column(
        children: <Widget>[
          ListFilters(
            fields: <ListSearchField>[
              ListSearchField(controller: _name, label: 'Search by name'),
              ListSearchField(
                controller: _email,
                label: 'Search by email',
                icon: Icons.alternate_email,
              ),
            ],
            includeDeleted: state.query.includeDeleted,
            onSearch: () =>
                _controller.search(name: _name.text, email: _email.text),
            onIncludeDeletedChanged: _controller.setIncludeDeleted,
          ),
          Expanded(
            // AF-28c — the scope is not one this admin owns. AF-28b — the
            // returned errors, with a retry.
            child: ListScaffold(
              state: state,
              onRetry: _controller.load,
              forbidden: ListForbidden.scope(
                onAction: () => context.go('/scopes'),
              ),
              empty: _empty,
              loaded: (GoogleUserListLoaded loaded) =>
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
            ),
          ),
        ],
      ),
    );
  }

  /// AF-28a — nobody has signed in with Google here, which is a different
  /// thing from a search that matched nothing. When the scope has the feature
  /// switched off, that is the reason, and UI-31's screen is where it is
  /// switched on.
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
      actionLabel: (signInOff ?? false) ? 'Sign-in settings' : null,
      onAction: (signInOff ?? false)
          ? () => context.go('/scopes/${widget.scopeId}/sign-in-settings')
          : null,
    );
  }
}
