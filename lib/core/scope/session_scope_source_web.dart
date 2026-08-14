import 'package:web/web.dart' as web;

import 'scope_source.dart';

/// Reads the scope the calling application left in session storage.
///
/// Session storage rather than a cookie, deliberately: it is scoped to the tab,
/// so two tabs can act in two scopes; it is never attached to a request, so the
/// scope cannot become a header the API did not ask for; and it dies with the
/// tab, so a scope does not outlive the visit on a shared machine.
ScopeSource sessionScopeSource({String? fallback}) =>
    _SessionStorageScopeSource(fallback);

class _SessionStorageScopeSource implements ScopeSource {
  const _SessionStorageScopeSource(this._fallback);

  /// Used when the caller left nothing — a build that is opened directly
  /// rather than handed off to.
  final String? _fallback;

  @override
  String? read() {
    final stored = web.window.sessionStorage.getItem(scopeStorageKey);

    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    return FixedScopeSource(_fallback).read();
  }
}
