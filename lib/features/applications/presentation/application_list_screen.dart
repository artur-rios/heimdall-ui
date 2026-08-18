import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
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
        label: const Text('New application'),
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
              ApplicationListLoading() => const CollectionLoading(),
              // AF-20c — the scope is not one this admin owns.
              ApplicationListFailed(isForbidden: true) => CollectionEmpty(
                title: 'Not available for your role',
                message:
                    'This scope is not one you administer. Nothing is '
                    'wrong with your session.',
                icon: Icons.lock_person_outlined,
                actionLabel: 'Back to scopes',
                onAction: () => context.go('/scopes'),
              ),
              // AF-20b — the returned errors, with a retry.
              ApplicationListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              ApplicationListLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                _empty(query, createRoute),
              final ApplicationListLoaded loaded =>
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
            },
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
