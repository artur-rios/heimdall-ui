import 'package:flutter/material.dart';

/// Validates the form behind [formKey] and, when it refuses, brings the first
/// refused field into view.
///
/// `validate()` alone marks every refused field, but a field scrolled out of
/// sight shows its message where nobody is looking, and the button that was
/// pressed then appears to do nothing at all. Every form submits through this
/// so that a refusal is always something the person can see.
bool validateAndReveal(GlobalKey<FormState> formKey) {
  final form = formKey.currentState;

  if (form == null) {
    return false;
  }

  final refused = form.validateGranularly();

  if (refused.isEmpty) {
    return true;
  }

  // Fields register in build order, so the first refused one is the one
  // nearest the top of the form.
  final field = refused.first;

  if (field.mounted) {
    Scrollable.ensureVisible(
      field.context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 200),
    );
  }

  return false;
}

/// Says why a save control is disabled when the form matches what is stored,
/// rather than leaving a greyed-out button to explain itself.
class NothingToSaveHint extends StatelessWidget {
  const NothingToSaveHint({super.key});

  /// The sentence shown, kept in one place for every form that uses it.
  static const String message = 'No changes to save yet.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A requirement the form cannot express as a text field — an owner still to
/// be chosen, say — shown the way a field's own error is.
class FormRequirementError extends StatelessWidget {
  const FormRequirementError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      message,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}
