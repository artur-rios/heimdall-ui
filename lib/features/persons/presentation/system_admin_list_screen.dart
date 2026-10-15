import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/person.dart';
import 'system_admin_list_controller.dart';

/// UI-38 — who holds full access, for a System Admin to see.
class SystemAdminListScreen extends ConsumerStatefulWidget {
  const SystemAdminListScreen({super.key});

  @override
  ConsumerState<SystemAdminListScreen> createState() =>
      _SystemAdminListScreenState();
}

class _SystemAdminListScreenState extends ConsumerState<SystemAdminListScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The provider is autoDispose, so there are no remembered filters to put
    // back in the fields.
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.load());
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  SystemAdminListController get _controller =>
      ref.read(systemAdminListControllerProvider.notifier);

  void _search() => _controller.search(name: _name.text, email: _email.text);

  void _clearFilters() {
    _name.clear();
    _email.clear();
    _controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(systemAdminListControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final me = session is Authenticated ? session.principal.id : null;
    final theme = Theme.of(context);

    return AppShell(
      currentRoute: '/',
      title: const Text('System Admins'),
      backRoute: '/',
      backTooltip: 'Back to Home',
      body: Column(
        children: <Widget>[
          _Filters(name: _name, email: _email, onSearch: _search),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'System Admins can administer every scope. Deleted and '
                'restricted accounts are not listed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (state) {
              SystemAdminListLoading() => const CollectionLoading(),
              // AF-38c — only a System Admin may list System Admins.
              SystemAdminListFailed(isForbidden: true) => CollectionEmpty(
                title: 'Not available for your role',
                message:
                    'Only a System Admin may see who the System Admins '
                    'are. Nothing is wrong with your session.',
                icon: Icons.lock_person_outlined,
                actionLabel: 'Back to Home',
                onAction: () => context.go('/'),
              ),
              SystemAdminListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              SystemAdminListLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                query.isFiltered
                    ? CollectionEmpty(
                        title: 'No System Admins match.',
                        message: 'Nothing here matches what you searched for.',
                        icon: Icons.search_off_outlined,
                        actionLabel: 'Clear filters',
                        onAction: _clearFilters,
                      )
                    : const CollectionEmpty(
                        title: 'No System Admins.',
                        message: 'There are no System Admins to show.',
                        icon: Icons.admin_panel_settings_outlined,
                      ),
              final SystemAdminListLoaded loaded =>
                AdaptiveCollection<PersonSummary>(
                  items: loaded.page.items,
                  busy: loaded.busy,
                  pageNumber: loaded.page.pageNumber,
                  totalPages: loaded.page.totalPages,
                  totalItems: loaded.page.totalItems,
                  onPageChanged: _controller.goToPage,
                  onTap: (admin) => context.go('/persons/${admin.id}'),
                  title: (admin) =>
                      admin.id == me ? '${admin.name} (you)' : admin.name,
                  // The email is the subtitle, which the table shows under the
                  // name, so there is no column of its own.
                  subtitle: (admin) => admin.email,
                  columns: const <CollectionColumn<PersonSummary>>[],
                ),
            },
          ),
        ],
      ),
    );
  }
}

/// The two search fields; Enter in either one searches.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.name,
    required this.email,
    required this.onSearch,
  });

  final TextEditingController name;
  final TextEditingController email;
  final VoidCallback onSearch;

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
      ],
    ),
  );
}
