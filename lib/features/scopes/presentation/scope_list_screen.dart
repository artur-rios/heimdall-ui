import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/scope.dart';
import 'scope_list_controller.dart';

/// UI-10 — the scope listing.
///
/// What it lists is the API's answer, not a filtered view of everything: a
/// Scope Admin is returned only the scopes they own (AF-10c), and nothing here
/// second-guesses that.
class ScopeListScreen extends ConsumerStatefulWidget {
  const ScopeListScreen({super.key});

  @override
  ConsumerState<ScopeListScreen> createState() => _ScopeListScreenState();
}

class _ScopeListScreenState extends ConsumerState<ScopeListScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(scopeListControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    ref.read(scopeListControllerProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scopeListControllerProvider);
    final controller = ref.read(scopeListControllerProvider.notifier);
    final session = ref.watch(sessionControllerProvider);
    // AF-10c: only a System Admin may create a scope, so nobody else is shown
    // the control. The API refuses either way.
    final mayCreate =
        session is Authenticated && session.principal.isSystemAdmin;

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('Scopes'),
      floatingActionButton: mayCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/scopes/new'),
              icon: const Icon(Icons.add),
              label: const Text('New scope'),
            )
          : null,
      body: Column(
        children: <Widget>[
          _Filters(
            search: _search,
            includeDeleted: state.query.includeDeleted,
            onSearch: controller.search,
            onIncludeDeletedChanged: controller.setIncludeDeleted,
          ),
          Expanded(
            child: switch (state) {
              ScopeListLoading() => const CollectionLoading(),
              ScopeListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: controller.load,
              ),
              ScopeListLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                _empty(query: query, mayCreate: mayCreate),
              final ScopeListLoaded loaded => AdaptiveCollection<Scope>(
                items: loaded.page.items,
                busy: loaded.busy,
                reservesFloatingAction: mayCreate,
                pageNumber: loaded.page.pageNumber,
                totalPages: loaded.page.totalPages,
                totalItems: loaded.page.totalItems,
                onPageChanged: controller.goToPage,
                onTap: (scope) => context.go('/scopes/${scope.id}'),
                title: (scope) => scope.name,
                subtitle: (scope) => scope.description,
                columns: <CollectionColumn<Scope>>[
                  CollectionColumn<Scope>(
                    label: 'Google Sign-In',
                    cell: (scope) =>
                        Text(scope.googleSignInEnabled ? 'On' : 'Off'),
                  ),
                  CollectionColumn<Scope>(
                    label: 'Owners',
                    cell: (scope) => Text('${scope.ownerCount}'),
                  ),
                  CollectionColumn<Scope>(
                    label: 'State',
                    cell: (scope) =>
                        Text(scope.isDeleted ? 'Deleted' : 'Active'),
                  ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }

  /// AF-10a — an empty listing and an empty search are different situations,
  /// and each has its own next action.
  Widget _empty({required ScopeQuery query, required bool mayCreate}) =>
      query.isFiltered
      ? CollectionEmpty(
          title: 'No scopes matched',
          message:
              'Nothing here matches what you searched for. Clearing the '
              'filters shows the full listing again.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Clear filters',
          onAction: _clearFilters,
        )
      : CollectionEmpty(
          title: 'No scopes yet',
          message: mayCreate
              ? 'Scopes are how Heimdall separates one tenant from another. '
                    'Create the first one to get started.'
              : 'You do not own any scopes yet. A System Admin can add you as '
                    'an owner of one.',
          icon: Icons.domain_outlined,
          actionLabel: mayCreate ? 'New scope' : null,
          onAction: mayCreate ? () => context.go('/scopes/new') : null,
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
  final ValueChanged<String> onSearch;
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
                onPressed: () => onSearch(search.text),
              ),
            ),
            onSubmitted: onSearch,
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
