import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../domain/scope_permission.dart';
import 'permission_list_controller.dart';

/// UI-24 — the permissions of one scope.
class PermissionListScreen extends ConsumerStatefulWidget {
  const PermissionListScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<PermissionListScreen> createState() =>
      _PermissionListScreenState();
}

class _PermissionListScreenState extends ConsumerState<PermissionListScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(permissionListControllerProvider(widget.scopeId).notifier)
          .load(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  PermissionListController get _controller =>
      ref.read(permissionListControllerProvider(widget.scopeId).notifier);

  void _clearFilters() {
    _search.clear();
    _controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permissionListControllerProvider(widget.scopeId));
    final createRoute = '/scopes/${widget.scopeId}/permissions/new';

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('Permissions'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the scope',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scopes/${widget.scopeId}'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(createRoute),
        icon: const Icon(Icons.add),
        label: const Text('New permission'),
      ),
      body: Column(
        children: <Widget>[
          _Filters(
            search: _search,
            includeDeleted: state.query.includeDeleted,
            onSearch: () => _controller.search(_search.text),
            onIncludeDeletedChanged: _controller.setIncludeDeleted,
          ),
          Expanded(
            child: switch (state) {
              PermissionListLoading() => const CollectionLoading(),
              // AF-24c — the scope is not one this admin owns.
              PermissionListFailed(isForbidden: true) => CollectionEmpty(
                title: 'Not available for your role',
                message:
                    'This scope is not one you administer. Nothing is '
                    'wrong with your session.',
                icon: Icons.lock_person_outlined,
                actionLabel: 'Back to scopes',
                onAction: () => context.go('/scopes'),
              ),
              // AF-24b — the returned errors, with a retry.
              PermissionListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              PermissionListLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                _empty(query, createRoute),
              final PermissionListLoaded loaded =>
                AdaptiveCollection<ScopePermission>(
                  items: loaded.page.items,
                  busy: loaded.busy,
                  reservesFloatingAction: true,
                  pageNumber: loaded.page.pageNumber,
                  totalPages: loaded.page.totalPages,
                  totalItems: loaded.page.totalItems,
                  onPageChanged: _controller.goToPage,
                  onTap: (permission) => context.go(
                    '/scopes/${widget.scopeId}/permissions/${permission.id}',
                  ),
                  title: (permission) => permission.name,
                  subtitle: (permission) => permission.description,
                  columns: <CollectionColumn<ScopePermission>>[
                    CollectionColumn<ScopePermission>(
                      label: 'In tokens',
                      // FR-PM-04: a permission issued in the scope's tokens is
                      // a different thing from one that is only recorded.
                      cell: (permission) =>
                          Text(permission.includeAsJwtClaim ? 'Yes' : 'No'),
                    ),
                    CollectionColumn<ScopePermission>(
                      label: 'State',
                      cell: (permission) =>
                          Text(permission.isDeleted ? 'Deleted' : 'Active'),
                    ),
                  ],
                ),
            },
          ),
        ],
      ),
    );
  }

  /// AF-24a — an empty scope and an empty search are different situations.
  Widget _empty(PermissionQuery query, String createRoute) => query.isFiltered
      ? CollectionEmpty(
          title: 'No permissions matched',
          message:
              'Nothing here matches what you searched for. Clearing the '
              'filters shows them all again.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Clear filters',
          onAction: _clearFilters,
        )
      : CollectionEmpty(
          title: 'No permissions yet',
          message:
              'A permission is something this scope’s applications can '
              'check for. Create the first one to get started.',
          icon: Icons.key_outlined,
          actionLabel: 'New permission',
          onAction: () => context.go(createRoute),
        );
}

/// The search field and the include-deleted switch.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.search,
    required this.includeDeleted,
    required this.onSearch,
    required this.onIncludeDeletedChanged,
  });

  final TextEditingController search;
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
          width: 320,
          child: TextField(
            controller: search,
            decoration: InputDecoration(
              labelText: 'Search by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.arrow_forward),
                onPressed: onSearch,
              ),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
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
