import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/formatting/date_time_format.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/adaptive_collection.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../home/presentation/home_screen.dart' show roleLabel;
import '../domain/audit_entry.dart';
import 'audit_log_controller.dart';

/// UI-34 — the audit trail, newest first, for a System Admin.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final TextEditingController _action = TextEditingController();
  final TextEditingController _actor = TextEditingController();
  final TextEditingController _target = TextEditingController();
  String? _actorError;
  String? _targetError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(auditLogControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _action.dispose();
    _actor.dispose();
    _target.dispose();
    super.dispose();
  }

  AuditLogController get _controller =>
      ref.read(auditLogControllerProvider.notifier);

  /// AF-34d — an identifier that is not one is refused here, and nothing is sent.
  void _submitActor(String text) {
    final accepted = _controller.setActor(text);
    setState(() => _actorError = accepted ? null : 'Enter an identifier.');
  }

  void _submitTarget(String text) {
    final accepted = _controller.setTarget(text);
    setState(() => _targetError = accepted ? null : 'Enter an identifier.');
  }

  void _filterByActor(String id) {
    _actor.text = id;
    _submitActor(id);
  }

  void _filterByTarget(String id) {
    _target.text = id;
    _submitTarget(id);
  }

  void _clearFilters() {
    _action.clear();
    _actor.clear();
    _target.clear();
    setState(() {
      _actorError = null;
      _targetError = null;
    });
    _controller.clearFilters();
  }

  Future<void> _pickDays(AuditLogFilter filter) async {
    final first = filter.firstDay;
    final last = filter.lastDay;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: first == null || last == null
          ? null
          : DateTimeRange(start: first, end: last),
    );

    if (range != null) {
      await _controller.setDays(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditLogControllerProvider);
    final filter = state.query.filter;

    return AppShell(
      currentRoute: '/audit-log',
      title: const Text('Audit log'),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(_datesLabel(context, filter)),
                  onPressed: () => _pickDays(filter),
                ),
                _field(
                  controller: _action,
                  label: 'Action',
                  hint: 'e.g. CreateScopeCommand',
                  onSubmitted: _controller.setAction,
                ),
                _field(
                  controller: _actor,
                  label: 'Actor',
                  error: _actorError,
                  onSubmitted: _submitActor,
                ),
                _field(
                  controller: _target,
                  label: 'Target',
                  error: _targetError,
                  onSubmitted: _submitTarget,
                ),
                _outcomeChip('All', null, filter),
                _outcomeChip('Succeeded', true, filter),
                _outcomeChip('Refused', false, filter),
                if (filter.isFiltered)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'Entries older than the attribution period show no actor, '
                'and filtering by actor cannot find them.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: switch (state) {
              AuditLogLoading() => const CollectionLoading(),
              // AF-34b, AF-34c, AF-34e — the returned errors, with a retry; the
              // filters above are kept.
              AuditLogFailed(:final failure) => CollectionFailed(
                failure: failure,
                onRetry: _controller.load,
              ),
              AuditLogLoaded(:final page, :final query)
                  when page.items.isEmpty =>
                _empty(query),
              final AuditLogLoaded loaded => AdaptiveCollection<AuditEntry>(
                items: loaded.page.items,
                busy: loaded.busy,
                pageNumber: loaded.page.pageNumber,
                totalPages: loaded.page.totalPages,
                totalItems: loaded.page.totalItems,
                onPageChanged: _controller.goToPage,
                title: (entry) => entry.action,
                subtitle: (entry) => _when(context, entry),
                columns: _columns(context),
              ),
            },
          ),
        ],
      ),
    );
  }

  String _datesLabel(BuildContext context, AuditLogFilter filter) {
    final first = filter.firstDay;
    final last = filter.lastDay;

    if (first == null || last == null) {
      return 'Dates';
    }

    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(first)} – '
        '${localizations.formatMediumDate(last)}';
  }

  String _when(BuildContext context, AuditEntry entry) =>
      entry.recordedAt == null
      ? '—'
      : formatDateTime(context, entry.recordedAt!);

  Widget _field({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onSubmitted,
    String? hint,
    String? error,
  }) => SizedBox(
    width: 220,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
    ),
  );

  Widget _outcomeChip(String label, bool? outcome, AuditLogFilter filter) =>
      ChoiceChip(
        label: Text(label),
        selected: filter.succeeded == outcome,
        onSelected: (_) => _controller.setOutcome(outcome),
      );

  /// AF-34a.
  Widget _empty(AuditLogQuery query) => query.filter.isFiltered
      ? CollectionEmpty(
          title: 'No entries match these filters.',
          message: 'Try a wider date range or fewer filters.',
          icon: Icons.filter_alt_off_outlined,
          actionLabel: 'Clear filters',
          onAction: _clearFilters,
        )
      : const CollectionEmpty(
          title: 'The audit log is empty.',
          message: 'Nothing has been recorded yet.',
          icon: Icons.history,
        );

  List<CollectionColumn<AuditEntry>> _columns(BuildContext context) {
    final theme = Theme.of(context);

    return <CollectionColumn<AuditEntry>>[
      CollectionColumn<AuditEntry>(
        label: 'When',
        cell: (entry) => Text(_when(context, entry)),
        // The subtitle already says it on a card.
        onCard: false,
      ),
      CollectionColumn<AuditEntry>(
        label: 'Outcome',
        cell: (entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Compact, so a chip and a reason fit a table row.
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              label: Text(entry.succeeded ? 'Succeeded' : 'Refused'),
              backgroundColor: entry.succeeded
                  ? null
                  : theme.colorScheme.errorContainer,
            ),
            if (entry.failureReason case final reason?)
              Text(reason, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      CollectionColumn<AuditEntry>(
        label: 'Actor',
        cell: (entry) => _IdCell(
          id: entry.actorId,
          label: entry.actorRole == null ? null : roleLabel(entry.actorRole!),
          empty: 'Cleared',
          copyTooltip: 'Copy the actor',
          filterTooltip: 'Filter by this actor',
          onFilter: _filterByActor,
        ),
      ),
      CollectionColumn<AuditEntry>(
        label: 'Target',
        cell: (entry) => _IdCell(
          id: entry.targetId,
          empty: '—',
          copyTooltip: 'Copy the target',
          filterTooltip: 'Filter by this target',
          onFilter: _filterByTarget,
        ),
      ),
    ];
  }
}

/// An identifier that can be copied or used as a filter, with the role that
/// came with it when there is one.
class _IdCell extends StatelessWidget {
  const _IdCell({
    required this.id,
    required this.empty,
    required this.copyTooltip,
    required this.filterTooltip,
    required this.onFilter,
    this.label,
  });

  final String? id;
  final String? label;
  final String empty;
  final String copyTooltip;
  final String filterTooltip;
  final ValueChanged<String> onFilter;

  Future<void> _copy(BuildContext context, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: id));
    messenger.showSnackBar(const SnackBar(content: Text('Identifier copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final id = this.id;

    if (id == null) {
      return Text(empty);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SelectableText(id),
              if (label case final label?)
                Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: copyTooltip,
          onPressed: () => _copy(context, id),
        ),
        IconButton(
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: filterTooltip,
          onPressed: () => onFilter(id),
        ),
      ],
    );
  }
}
