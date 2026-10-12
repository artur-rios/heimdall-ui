import 'package:flutter/material.dart';

import 'credential_field.dart';

/// A credential as an ordinary Flutter field. Off the web the platform's own
/// autofill service reads the [AutofillGroup] the fields sit in.
class CredentialField extends StatelessWidget {
  const CredentialField({
    required this.kind,
    required this.controller,
    required this.label,
    required this.validator,
    this.onSubmitted,
    this.enabled = true,
    super.key,
  });

  final CredentialKind kind;
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;

  /// Called when Enter is pressed in the field.
  final VoidCallback? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    obscureText: kind == CredentialKind.password,
    keyboardType: kind == CredentialKind.email
        ? TextInputType.emailAddress
        : null,
    autofillHints: <String>[
      kind == CredentialKind.email
          ? AutofillHints.email
          : AutofillHints.password,
    ],
    decoration: InputDecoration(labelText: label),
    onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    validator: validator,
  );
}

/// Tells the page's password manager that the credentials were submitted.
/// Off the web the platform's autofill service learns it from the
/// [AutofillGroup] closing, so there is nothing to do.
void announceCredentialsSubmitted() {}
