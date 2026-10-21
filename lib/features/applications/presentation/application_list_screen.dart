import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/list_filters.dart';
import '../../../shared/widgets/list_scaffold.dart';
import '../domain/application.dart';
import 'application_list_controller.dart';

/// UI-20 — the applications of one scope.
class ApplicationListScreen extends ConsumerStatefulWidget {
  const ApplicationListScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<ApplicationListScreen> createState() =>
      _ApplicationListScreenState();
}

class _ApplicationListScreenState extends ConsumerState<ApplicationListScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The listing remembers its filters between visits, so the fields say
    // what it is still filtered by rather than starting blank.
    final query = ref
        .read(applicationListControllerProvider(widget.scopeId))
        .query;
    _search.text = query.name;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(applicationListControllerProvider(widget.scopeId).notifier)
          .load(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ApplicationListController get _controller =>
      ref.read(applicationListControllerProvider(widget.scopeId).notifier);

  void _clearFilters() {
    _search.clear();
    _controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationListControllerProvider(widget.scopeId));
    final createRoute = '/scopes/${widget.scopeId}/applications/new';

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('Applications'),
      // Back from a record that may have been changed or deleted.
      onReturn: _controller.load,
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(createRoute),
        icon: const Icon(Icons.add),
        label: const Text('New application'),
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
              loaded: (ApplicationListLoaded loaded) =>
                  AdaptiveCollection<Application>(
                    items: loaded.page.items,
                    busy: loaded.busy,
                    reservesFloatingAction: true,
                    pageNumber: loaded.page.pageNumber,
                    totalPages: loaded.page.totalPages,
                    totalItems: loaded.page.totalItems,
                    onPageChanged: _controller.goToPage,
                    onTap: (application) => context.go(
                      '/scopes/${widget.scopeId}/applications/'
                      '${application.id}',
                    ),
                    title: (application) => application.name,
                    columns: <CollectionColumn<Application>>[
                      CollectionColumn<Application>(
                        label: 'Owner',
                        // FR-AP-08 and AF-20d: the owner's name where the API
                        // resolved one, their identifier where it did not.
                        cell: (application) =>
                            Text(loaded.ownerLabel(application.ownerId)),
                      ),
                      CollectionColumn<Application>(
                        label: 'State',
                        cell: (application) =>
                            Text(application.isDeleted ? 'Deleted' : 'Active'),
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// AF-20a — an empty scope and an empty search are different situations.
  Widget _empty(ApplicationQuery query, String createRoute) => query.isFiltered
      ? CollectionEmpty(
          title: 'No applications matched',
          message:
              'Nothing here matches what you searched for. Clearing the '
              'filters shows them all again.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Clear filters',
          onAction: _clearFilters,
        )
      : CollectionEmpty(
          title: 'No applications yet',
          message:
              'An application is something that uses this scope for its '
              'identity. Create the first one to get started.',
          icon: Icons.apps_outlined,
          actionLabel: 'New application',
          onAction: () => context.go(createRoute),
        );
}
