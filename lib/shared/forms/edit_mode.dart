import 'package:flutter/material.dart';

import 'form_feedback.dart';

/// How a field looks in a record's view mode and in its edit mode.
///
/// A record is shown read-only until the person asks to change it, so a stray
/// keystroke can never turn into an edit. In view mode the field drops its
/// outline and its character counter and reads as a labelled value; in edit
/// mode it is an ordinary input again.
InputDecoration recordFieldDecoration(
  BuildContext context, {
  required String label,
  required bool editing,
  String? helperText,
}) {
  if (editing) {
    return InputDecoration(labelText: label, helperText: helperText);
  }

  final scheme = Theme.of(context).colorScheme;

  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: scheme.surfaceContainerLow,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    // The counter is about typing, and nothing is being typed.
    counterText: '',
  );
}

/// A record's editable fields, with the control that unlocks them and the
/// controls that end the edit.
///
/// [editing] is owned by the screen. While it is `false` the section offers
/// **Edit** (when [mayEdit]); while it is `true` it offers **Cancel** and
/// **Save changes**, the latter disabled — and explained — until something
/// differs.
class EditableSection extends StatelessWidget {
  const EditableSection({
    required this.title,
    required this.editing,
    required this.mayEdit,
    required this.saving,
    required this.canSave,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
    required this.child,
    this.editLabel = 'Edit',
    super.key,
  });

  final String title;
  final bool editing;

  /// Whether this caller may change the record at all. A record they may not
  /// change is shown without the Edit control rather than with one that the
  /// API would refuse.
  final bool mayEdit;
  final bool saving;

  /// Whether anything differs from the stored record.
  final bool canSave;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final Widget child;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 48,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  if (editing)
                    Text(
                      'Editing',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else if (mayEdit)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(editLabel),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            child,
            if (editing) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: saving ? null : onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: (saving || !canSave) ? null : onSave,
                      child: saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
                    ),
                  ),
                ],
              ),
              // Says why Save is disabled.
              if (!saving && !canSave) const NothingToSaveHint(),
            ],
          ],
        ),
      ),
    );
  }
}
