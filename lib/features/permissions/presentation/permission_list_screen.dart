import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/list_filters.dart';
import '../../../shared/widgets/list_scaffold.dart';
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
    // The listing remembers its filters between visits, so the fields say
    // what it is still filtered by rather than starting blank.
    final query = ref
        .read(permissionListControllerProvider(widget.scopeId))
        .query;
    _search.text = query.name;
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
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(createRoute),
        icon: const Icon(Icons.add),
        label: const Text('New permission'),
      ),
      body: Column(
        children: <Widget>[
          ListFilters(
            fields: <ListSearchField>[
              ListSearchField(controller: _search, label: 'Search by name'),
            ],
            includeDeleted: state.query.includeDeleted,
            onSearch: () => _controller.search(_search.text),
            onIncludeDeletedChanged: _controller.setIncludeDeleted,
          ),
          Expanded(
            child: ListScaffold(
              state: state,
              onRetry: _controller.load,
              onForbiddenBack: () => context.go('/scopes'),
              empty: (query) => _empty(query, createRoute),
              loaded: (PermissionListLoaded loaded) =>
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
            ),
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
