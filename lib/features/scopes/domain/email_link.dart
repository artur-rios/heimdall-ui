/// The base links a scope's emails point at (UI-31): mirrored from the API's
/// `SetScopeEmailLinksCommandValidator`, so the form refuses what the API
/// would. The API stays the authority; this only spares the round trip.
library;

/// The longest link the API stores.
const int emailLinkMaxLength = 2048;

/// Why [value] is not a usable link, or `null` when it is — an empty one
/// included, since an empty link is a clear, not an error.
///
/// Deliberately not `Uri.isAbsolute`: that is false for a link with a
/// fragment, and a hash-routed web application's screens are exactly such
/// links (`https://app.example.com/#/verify-email`). The API accepts them.
String? validateEmailLink(String? value) {
  final link = value?.trim() ?? '';

  if (link.isEmpty) {
    return null;
  }

  if (link.length > emailLinkMaxLength) {
    return 'Use at most $emailLinkMaxLength characters.';
  }

  final uri = Uri.tryParse(link);
  final usable =
      uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;

  return usable ? null : 'Enter a full link starting with https:// or http://.';
}

/// [value] as it is sent: trimmed, and `null` when nothing is left, which the
/// API reads as "clear this link".
String? normalizeEmailLink(String? value) {
  final link = value?.trim() ?? '';

  return link.isEmpty ? null : link;
}
