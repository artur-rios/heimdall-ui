/// The API's own input limits, mirrored so a form refuses what the API would.
///
/// Each value is the one the API's validators enforce for every command that
/// takes the field (`MaximumLength` / `MinimumLength` in its FluentValidation
/// rules). The API stays the authority; matching it here only spares the
/// round trip and tells the person before they submit.
library;

/// Every name: scopes, persons, applications, and permissions.
const int nameMaxLength = 200;

/// Scope and permission descriptions.
const int descriptionMaxLength = 500;

/// The shortest password the API accepts when one is set — creating a person
/// or resetting a password. Signing in has no such rule: there, a short
/// password is simply a wrong one.
const int passwordMinLength = 8;

/// Validates a password being set, with the API's own wording for the length
/// rule (`PersonMessages.PasswordTooShort`, `AuthMessages.PasswordTooShort`).
///
/// The password is not trimmed: spaces are part of it on both sides of the
/// wire. A password of spaces alone is refused, as the API's `NotEmpty` does.
String? validateNewPassword(String? value, {required String emptyMessage}) {
  final password = value ?? '';

  if (password.trim().isEmpty) {
    return emptyMessage;
  }

  return password.length < passwordMinLength
      ? 'Password must be at least $passwordMinLength characters.'
      : null;
}

/// Whether [email] has the shape the API's `EmailAddress()` rule accepts:
/// exactly one `@`, with something on either side of it.
///
/// Deliberately no stricter than that rule. A tighter pattern would refuse
/// addresses the API takes; a looser one — any `@` at all — lets `a@`, `@a`,
/// and `a@b@c` through only for the API to answer "Email is not valid."
bool isPlausibleEmail(String email) {
  final at = email.indexOf('@');

  return at > 0 && at == email.lastIndexOf('@') && at < email.length - 1;
}
