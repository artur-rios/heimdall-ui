import 'package:web/web.dart' as web;

import '../scope/scope_source.dart';
import 'entry_link.dart';

/// Takes what the address the page was opened at carries, before the router
/// reads it. See [takeEntryLink].
EntryLink takePlatformEntryLink() => takeEntryLink(const _WindowBrowser());

class _WindowBrowser implements EntryBrowser {
  const _WindowBrowser();

  @override
  Uri get address => Uri.parse(web.window.location.href);

  // The entry's own state is kept: on a reload it is the router's.
  @override
  void replaceAddress(Uri address) => web.window.history.replaceState(
    web.window.history.state,
    '',
    address.toString(),
  );

  // Storage can be refused outright (a privacy setting, a sandboxed frame);
  // start-up goes on without it, as it would without a hand-off.
  @override
  void keepScope(String scopeId) {
    try {
      web.window.sessionStorage.setItem(scopeStorageKey, scopeId);
    } on Object {
      // Nothing kept: the build's fallback scope applies.
    }
  }

  @override
  void forgetLocal(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } on Object {
      // Storage that cannot be read holds nothing to forget.
    }
  }
}
