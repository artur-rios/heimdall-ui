import 'package:flutter/material.dart';

/// Asks before something that cannot simply be undone.
///
/// Returns `true` only when the user confirmed; dismissing the dialog any
/// other way is a "no", which is what the cancelled alternative flows of the
/// deletion use cases require.
Future<bool> showConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// Asks before something irreversible, and will not let the user agree until
/// they have typed [confirmationValue] exactly.
///
/// The typing is the point: it is what stops a permanent deletion from being
/// one careless tap, and it is why the confirm control stays disabled until the
/// value matches.
Future<bool> showTypeToConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmationValue,
  required String fieldLabel,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _TypeToConfirmDialog(
      title: title,
      message: message,
      confirmationValue: confirmationValue,
      fieldLabel: fieldLabel,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );

  return confirmed ?? false;
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmationValue,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmationValue;
  final String fieldLabel;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// An exact match, not a trimmed or case-folded one. A confirmation that
  /// accepts nearly the right value is not much of a confirmation.
  bool get _matches => _typed.text == widget.confirmationValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.message),
          const SizedBox(height: 16),
          Text(widget.confirmationValue, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _typed,
            autofocus: true,
            decoration: InputDecoration(labelText: widget.fieldLabel),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
