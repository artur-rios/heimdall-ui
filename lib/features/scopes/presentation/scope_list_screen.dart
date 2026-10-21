import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/list_filters.dart';
import '../../../shared/widgets/list_scaffold.dart';
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
    // The listing remembers its filters between visits, so the fields say
    // what it is still filtered by rather than starting blank.
    final query = ref.read(scopeListControllerProvider).query;
    _search.text = query.name;
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
    unawaited(ref.read(scopeListControllerProvider.notifier).clearFilters());
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
      // Back from a record that may have been changed or deleted.
      onReturn: controller.load,
      floatingActionButton: mayCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/scopes/new'),
              icon: const Icon(Icons.add),
              label: const Text('New scope'),
            )
          : null,
      body: Column(
        children: <Widget>[
          ListFilters(
            fields: <ListSearchField>[
              ListSearchField(controller: _search, label: 'Search by name'),
            ],
            includeDeleted: state.query.includeDeleted,
            onSearch: () => controller.search(_search.text),
            onIncludeDeletedChanged: controller.setIncludeDeleted,
          ),
          Expanded(
            child: ListScaffold(
              state: state,
              onRetry: controller.load,
              empty: (query) => _empty(query: query, mayCreate: mayCreate),
              loaded: (ScopeListLoaded loaded) => AdaptiveCollection<Scope>(
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
            ),
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
