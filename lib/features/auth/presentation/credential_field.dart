/// The sign-in screen's email and password fields.
///
/// Off the web they are ordinary Flutter text fields. On the web they are real
/// HTML inputs, because a password manager extension such as Bitwarden reads
/// the page's DOM: Flutter web only puts an `<input>` there while a field has
/// focus, gives the other field of the group no size, and removes both the
/// moment focus moves — into the extension's own menu, say — so the extension
/// never finds a login form it can fill.
library;

export 'credential_field_io.dart'
    if (dart.library.js_interop) 'credential_field_web.dart';

/// Which credential a field holds, which decides how browsers and password
/// managers recognise it.
enum CredentialKind { email, password }
