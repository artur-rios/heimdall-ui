import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/list_filters.dart';
import '../../../shared/widgets/list_scaffold.dart';
import '../../home/presentation/home_screen.dart';
import '../domain/person.dart';
import 'person_list_controller.dart';

/// UI-16 — the persons of one scope.
class PersonListScreen extends ConsumerStatefulWidget {
  const PersonListScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<PersonListScreen> createState() => _PersonListScreenState();
}

class _PersonListScreenState extends ConsumerState<PersonListScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The listing remembers its filters between visits, so the fields say
    // what it is still filtered by rather than starting blank.
    final query = ref.read(personListControllerProvider(widget.scopeId)).query;
    _name.text = query.name;
    _email.text = query.email;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(personListControllerProvider(widget.scopeId).notifier)
          .load(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  PersonListController get _controller =>
      ref.read(personListControllerProvider(widget.scopeId).notifier);

  void _search() => _controller.search(name: _name.text, email: _email.text);

  void _clearFilters() {
    _name.clear();
    _email.clear();
    _controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personListControllerProvider(widget.scopeId));

    return AppShell(
      currentRoute: '/scopes',
      title: const Text('Persons'),
      // Back from a record that may have been changed or deleted.
      onReturn: _controller.load,
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/scopes/${widget.scopeId}/persons/new'),
        icon: const Icon(Icons.add),
        label: const Text('New person'),
      ),
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
            onSearch: _search,
            onIncludeDeletedChanged: _controller.setIncludeDeleted,
          ),
          Expanded(
            // AF-16c — the scope is not one this admin owns. AF-16b — the
            // returned errors, with a retry that keeps the filters.
            child: ListScaffold(
              state: state,
              onRetry: _controller.load,
              forbidden: ListForbidden.scope(
                onAction: () => context.go('/scopes'),
              ),
              empty: _empty,
              loaded: (PersonListLoaded loaded) => AdaptiveCollection<Person>(
                items: loaded.page.items,
                busy: loaded.busy,
                reservesFloatingAction: true,
                pageNumber: loaded.page.pageNumber,
                totalPages: loaded.page.totalPages,
                totalItems: loaded.page.totalItems,
                onPageChanged: _controller.goToPage,
                onTap: (person) => context.go(
                  '/scopes/${widget.scopeId}/persons/${person.id}',
                ),
                title: (person) => person.name,
                subtitle: (person) => person.email,
                columns: <CollectionColumn<Person>>[
                  CollectionColumn<Person>(
                    label: 'Role',
                    cell: (person) => Text(roleLabel(person.role)),
                  ),
                  CollectionColumn<Person>(
                    label: 'Verified',
                    cell: (person) => Text(person.emailVerified ? 'Yes' : 'No'),
                  ),
                  CollectionColumn<Person>(
                    label: 'State',
                    cell: (person) =>
                        Text(person.isDeleted ? 'Deleted' : 'Active'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AF-16a — an empty scope and an empty search are different situations, and
  /// each has its own next action.
  Widget _empty(PersonQuery query) => query.isFiltered
      ? CollectionEmpty(
          title: 'No persons matched',
          message:
              'Nothing here matches what you searched for. Clearing the '
              'filters shows everyone in this scope again.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Clear filters',
          onAction: _clearFilters,
        )
      : CollectionEmpty(
          title: 'No persons yet',
          message:
              'This scope has nobody in it. Creating the first person '
              'sends them a verification email.',
          icon: Icons.people_outline,
          actionLabel: 'New person',
          onAction: () => context.go('/scopes/${widget.scopeId}/persons/new'),
        );
}
