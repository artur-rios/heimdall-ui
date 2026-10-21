import 'package:flutter/material.dart';

/// Asks before something that cannot simply be undone.
///
/// Returns `true` only when the user confirmed; dismissing the dialog any
/// other way is a "no", which is what the cancelled alternative flows of the
/// deletion use cases require.
///
/// [destructive] marks a confirmation that loses something (a deletion, a
/// revocation, discarded work): the confirm button takes the error colours and
/// Cancel, not the confirm button, takes the focus, so Enter pressed by reflex
/// cancels instead of destroying.
Future<bool> showConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      // Scrolls rather than overflowing when a phone's keyboard is open.
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          autofocus: destructive,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: _confirmStyle(context, destructive),
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
///
/// [destructive] gives the confirm button the error colours. The text field
/// keeps the focus either way: typing is what the user came to do, and Enter
/// confirms nothing until the value matches.
Future<bool> showTypeToConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmationValue,
  required String fieldLabel,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
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
      destructive: destructive,
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
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmationValue;
  final String fieldLabel;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

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

  /// A match of the trimmed texts, not a case-folded one: a name another client
  /// stored with stray whitespace is shown, and must be typed, without it.
  /// A confirmation that accepts nearly the right value is not much of one.
  bool get _matches => _typed.text.trim() == widget.confirmationValue.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      // Scrolls rather than overflowing when a phone's keyboard is open.
      scrollable: true,
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
          style: _confirmStyle(context, widget.destructive),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// The confirm button's look: the error colours when the action [destructive]ly
/// loses something, the theme's own otherwise.
ButtonStyle? _confirmStyle(BuildContext context, bool destructive) {
  if (!destructive) {
    return null;
  }

  final scheme = Theme.of(context).colorScheme;

  return FilledButton.styleFrom(
    backgroundColor: scheme.error,
    foregroundColor: scheme.onError,
  );
}
