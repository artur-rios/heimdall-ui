import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../domain/outstanding_erasure.dart';
import 'reconciliation_controller.dart';

/// UI-32 — re-applies the erasures logged since a backup was taken.
Future<void> showReconciliationDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _ReconciliationDialog(),
);

class _ReconciliationDialog extends ConsumerStatefulWidget {
  const _ReconciliationDialog();

  @override
  ConsumerState<_ReconciliationDialog> createState() =>
      _ReconciliationDialogState();
}

class _ReconciliationDialogState extends ConsumerState<_ReconciliationDialog> {
  // Held here, not in the provider, so the paste survives every state change
  // (AF-32f, AF-32g).
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(reconciliationControllerProvider.notifier);
    final parsed = controller.check(_paste.text);

    if (parsed == null) {
      return;
    }

    final count = parsed.ids.length;
    final confirmed = await showConfirm(
      context: context,
      title: count == 1
          ? 'Re-apply erasure to 1 identifier?'
          : 'Re-apply erasure to $count identifiers?',
      message:
          'Each identity the restore brought back is anonymised again. '
          'Running this twice anonymises nothing extra.',
      confirmLabel: 'Re-apply',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await controller.send(parsed.ids);
  }

  Future<void> _copyNotFound(List<String> ids) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: ids.join('\n')));
    messenger.showSnackBar(
      const SnackBar(content: Text('Identifiers copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reconciliationControllerProvider);

    return AlertDialog(
      scrollable: true,
      title: const Text('Re-apply erasures'),
      content: switch (state) {
        ReconciliationDone(:final outcome) => _result(context, outcome),
        _ => _form(state),
      },
      actions: switch (state) {
        ReconciliationDone() => <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
        _ => <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: state is ReconciliationSending ? null : _submit,
            child: const Text('Re-apply'),
          ),
        ],
      },
    );
  }

  Widget _form(ReconciliationState state) {
    final editing = state is ReconciliationEditing ? state : null;
    final failure = editing?.failure;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Paste the identifiers the anonymisation pass logged since the '
          'backup was taken. Commas, spaces and new lines all separate them.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _paste,
          minLines: 6,
          maxLines: 12,
          decoration: InputDecoration(
            labelText: 'Identifiers',
            errorText: editing == null
                ? null
                : editing.empty
                ? 'Paste at least one identifier.'
                : editing.invalid.isNotEmpty
                ? 'These are not identifiers: ${editing.invalid.join(', ')}'
                : null,
          ),
        ),
        if (failure != null) ...<Widget>[
          const SizedBox(height: 16),
          ErrorBanner(failure: failure),
        ],
      ],
    );
  }

  Widget _result(BuildContext context, ReconciliationOutcome outcome) {
    final notFound = outcome.notFound;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Anonymised: ${outcome.anonymised}'),
        Text('Already anonymised: ${outcome.alreadyAnonymised}'),
        Text('Not found: ${notFound.length}'),
        if (notFound.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SelectableText(
            notFound.join('\n'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy'),
            onPressed: () => _copyNotFound(notFound),
          ),
          const SizedBox(height: 8),
          Text(
            'Not found is the ordinary case for most of the ledger.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
