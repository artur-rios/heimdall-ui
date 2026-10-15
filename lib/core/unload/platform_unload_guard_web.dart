import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'unload_guard.dart';

/// Has the browser ask before the tab is closed or refreshed.
UnloadGuard platformUnloadGuard() => _BeforeUnloadGuard();

class _BeforeUnloadGuard implements UnloadGuard {
  _BeforeUnloadGuard() : _listener = _confirm.toJS;

  // One function object, so the one that was added is the one removed.
  final JSFunction _listener;
  bool _registered = false;

  @override
  void register() {
    if (!_registered) {
      web.window.addEventListener('beforeunload', _listener);
      _registered = true;
    }
  }

  @override
  void unregister() {
    if (_registered) {
      web.window.removeEventListener('beforeunload', _listener);
      _registered = false;
    }
  }

  // The browser shows its own wording; a page cannot choose it. Setting
  // `returnValue` as well covers browsers that predate `preventDefault` here.
  static void _confirm(web.BeforeUnloadEvent event) {
    event
      ..preventDefault()
      ..returnValue = 'unsaved';
  }
}
