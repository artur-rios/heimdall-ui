import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
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
      actions: <Widget>[
        IconButton(
          tooltip: 'Back to the scope',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scopes/${widget.scopeId}'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/scopes/${widget.scopeId}/persons/new'),
        icon: const Icon(Icons.add),
        label: const Text('New person'),
      ),
      body: Column(
        children: <Widget>[
          _Filters(
            name: _name,
            email: _email,
            includeDeleted: state.query.includeDeleted,
            onSearch: _search,
            onIncludeDeletedChanged: _controller.setIncludeDeleted,
          ),
          Expanded(
            child: switch (state) {
              PersonListLoading() => const CollectionLoading(),
              // AF-16c — the scope is not one this admin owns.
              PersonListFailed(isForbidden: true) => CollectionEmpty(
                title: 'Not available for your role',
                message:
                    'This scope is not one you administer. Nothing is '
                    'wrong with your session.',
                icon: Icons.lock_person_outlined,
                actionLabel: 'Back to scopes',
                onAction: () => context.go('/scopes'),
              ),
              // AF-16b — the returned errors, with a retry that keeps the
              // filters.
              PersonListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              PersonListLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                _empty(query),
              final PersonListLoaded loaded => AdaptiveCollection<Person>(
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
            },
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

/// The two search fields and the include-deleted switch.
///
/// Two fields rather than one: the API filters by name and by email
/// separately, and collapsing them here would mean guessing which one the user
/// meant.
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
