import 'package:web/web.dart' as web;

import 'scope_source.dart';

/// Reads the scope kept in session storage: the `?scope=` the calling
/// application put on the entry URL, copied there at start-up, or a value a
/// caller on the UI's own origin wrote itself.
///
/// Session storage rather than a cookie, deliberately: it is scoped to the tab,
/// so two tabs can act in two scopes; it is never attached to a request, so the
/// scope cannot become a header the API did not ask for; and it dies with the
/// tab, so a scope does not outlive the visit on a shared machine.
ScopeSource sessionScopeSource({String? fallback}) => StoredScopeSource(
  () => web.window.sessionStorage.getItem(scopeStorageKey),
  fallback: fallback,
);
