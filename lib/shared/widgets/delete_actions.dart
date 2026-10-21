import 'package:flutter/material.dart';

import '../../core/result/result.dart';
import '../retention_window.dart';
import 'confirm_dialog.dart';
import 'failure_banner.dart';

/// The two deletions of a record, kept apart from the rest of a detail screen
/// because neither is an ordinary edit: the logical delete, which hides the
/// record, and the permanent one, which erases it and asks for [fieldLabel]
/// typed out first.
///
/// One widget carries the flow and its wording so the five detail screens say
/// the same thing. The wording is what the API does: it has no restore
/// endpoint, so a logical delete can be undone only by an operator, in the
/// database, within the retention window (see [administrativeDeletionWindow]).
class DeleteActions extends StatelessWidget {
  const DeleteActions({
    required this.noun,
    required this.confirmationValue,
    required this.fieldLabel,
    required this.permanentConsequence,
    required this.onDelete,
    required this.onDeletePermanently,
    required this.deleting,
    this.recordName,
    this.failure,
    this.extraWarning,
    this.anonymises = false,
    this.mayDeletePermanently = true,
    this.blockedReason,
    super.key,
  });

  /// What is deleted, lower case: "person", "scope", "Google user".
  final String noun;

  /// The record's name, to head the dialogs with; "this [noun]" when null.
  final String? recordName;

  /// What the user must type before a permanent deletion is allowed.
  final String confirmationValue;

  /// The label of the field they type it into, such as "Email address".
  final String fieldLabel;

  /// What a permanent deletion erases, as a sentence.
  final String permanentConsequence;

  /// An extra sentence of caution for both dialogs and the panel, when the
  /// record can come back by itself.
  final String? extraWarning;

  /// Whether the retention window ends in anonymisation, which cannot be
  /// reversed: true for persons and Google users.
  final bool anonymises;

  final Future<void> Function() onDelete;
  final Future<void> Function() onDeletePermanently;

  /// Whether a request is in flight, which disables both buttons.
  final bool deleting;

  /// The API's refusal of the last attempt, shown with the record still open.
  final Failure? failure;

  /// Whether the caller may erase the record: a Scope Admin never sees the
  /// permanent deletion.
  final bool mayDeletePermanently;

  /// Why the caller may delete nothing here, which replaces the explanation
  /// and disables both buttons; null when they may.
  final String? blockedReason;

  String get _hides => <String>[
    'This hides the $noun. Only an operator can restore it, from the '
        'database, within the retention window.',
    if (anonymises)
      'After $administrativeDeletionWindowText, their personal data is '
          'anonymised and cannot be restored.',
    ?extraWarning,
  ].join(' ');

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirm(
      context: context,
      title: 'Delete ${recordName ?? 'this $noun'}?',
      message: _hides,
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (confirmed && context.mounted) {
      await onDelete();
    }
  }

  /// The confirm control stays disabled until the value matches.
  Future<void> _confirmDeletePermanently(BuildContext context) async {
    final confirmed = await showTypeToConfirm(
      context: context,
      title: 'Delete ${recordName ?? 'this $noun'} permanently?',
      message: <String>[
        permanentConsequence,
        'This cannot be undone.',
        ?extraWarning,
        'Type the ${fieldLabel.toLowerCase()} to confirm:',
      ].join(' '),
      confirmationValue: confirmationValue,
      fieldLabel: fieldLabel,
      confirmLabel: 'Delete permanently',
      destructive: true,
    );

    if (confirmed && context.mounted) {
      await onDeletePermanently();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocked = deleting || blockedReason != null;

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Delete this $noun',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              blockedReason ??
                  <String>[
                    'Deleting hides the $noun, and only an operator can '
                        'restore it. Deleting permanently erases it.',
                    ?extraWarning,
                  ].join(' '),
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            if (failure case final refusal?) ...<Widget>[
              const SizedBox(height: 16),
              ErrorBanner(failure: refusal),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: blocked ? null : () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: Text('Delete $noun'),
                ),
                if (mayDeletePermanently)
                  FilledButton.icon(
                    onPressed: blocked
                        ? null
                        : () => _confirmDeletePermanently(context),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete permanently'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
