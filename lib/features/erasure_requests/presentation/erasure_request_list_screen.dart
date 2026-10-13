import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../domain/outstanding_erasure.dart';
import 'erasure_request_list_controller.dart';
import 'reconciliation_dialog.dart';

/// UI-32 — the erasure requests the anonymisation pass has not carried out yet.
class ErasureRequestListScreen extends ConsumerStatefulWidget {
  const ErasureRequestListScreen({super.key});

  @override
  ConsumerState<ErasureRequestListScreen> createState() =>
      _ErasureRequestListScreenState();
}

class _ErasureRequestListScreenState
    extends ConsumerState<ErasureRequestListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(erasureRequestListControllerProvider.notifier).load();
    });
  }

  ErasureRequestListController get _controller =>
      ref.read(erasureRequestListControllerProvider.notifier);

  Future<void> _copy(String subjectId) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: subjectId));
    messenger.showSnackBar(const SnackBar(content: Text('Identifier copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(erasureRequestListControllerProvider);

    return AppShell(
      currentRoute: '/erasure-requests',
      title: const Text('Erasure requests'),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilterChip(
                  label: const Text('Overdue only'),
                  selected: state.query.overdueOnly,
                  onSelected: _controller.setOverdueOnly,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Re-apply erasures'),
                  onPressed: () => showReconciliationDialog(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'Names and email addresses are not shown: these people have '
                'asked to be erased.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: switch (state) {
              ErasureRequestListLoading() => const CollectionLoading(),
              // AF-32c and AF-32h — the returned errors, with a retry.
              ErasureRequestListFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              ErasureRequestListLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                _empty(query),
              final ErasureRequestListLoaded loaded =>
                AdaptiveCollection<OutstandingErasure>(
                  items: loaded.page.items,
                  busy: loaded.busy,
                  pageNumber: loaded.page.pageNumber,
                  totalPages: loaded.page.totalPages,
                  totalItems: loaded.page.totalItems,
                  onPageChanged: _controller.goToPage,
                  // The collection's title is plain text, so the identifier
                  // keeps the default face rather than a monospace one.
                  title: (erasure) => erasure.subjectId,
                  subtitle: (erasure) =>
                      erasure.isGoogleUser ? 'Google user' : 'Person',
                  columns: _columns(context),
                ),
            },
          ),
        ],
      ),
    );
  }

  /// AF-32a and AF-32b.
  Widget _empty(ErasureRequestQuery query) => CollectionEmpty(
    title: query.overdueOnly
        ? 'Nothing is overdue.'
        : 'No outstanding erasure requests.',
    message: query.overdueOnly
        ? 'Every outstanding request is still within its deadline.'
        : 'Every request made so far has been carried out.',
    icon: Icons.task_alt_outlined,
    actionLabel: query.overdueOnly ? 'Show all' : null,
    onAction: query.overdueOnly
        ? () => _controller.setOverdueOnly(false)
        : null,
  );

  List<CollectionColumn<OutstandingErasure>> _columns(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String date(DateTime? at) =>
        at == null ? '—' : localizations.formatMediumDate(at.toLocal());

    return <CollectionColumn<OutstandingErasure>>[
      CollectionColumn<OutstandingErasure>(
        label: 'Kind',
        cell: (erasure) =>
            Text(erasure.isGoogleUser ? 'Google user' : 'Person'),
        // The subtitle already says it on a card.
        onCard: false,
      ),
      CollectionColumn<OutstandingErasure>(
        label: 'Requested',
        cell: (erasure) => Text(date(erasure.requestedAt)),
      ),
      CollectionColumn<OutstandingErasure>(
        label: 'Due',
        cell: (erasure) => Text(date(erasure.dueAt)),
      ),
      CollectionColumn<OutstandingErasure>(
        label: 'Status',
        cell: (erasure) => erasure.overdue
            ? Chip(
                label: const Text('Overdue'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              )
            : const Text('Within deadline'),
      ),
      CollectionColumn<OutstandingErasure>(
        label: 'Blocked',
        cell: (erasure) => Text(erasure.blockedReason ?? '—'),
      ),
      CollectionColumn<OutstandingErasure>(
        label: 'Copy',
        cell: (erasure) => IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: 'Copy the identifier',
          onPressed: () => _copy(erasure.subjectId),
        ),
      ),
    ];
  }
}
