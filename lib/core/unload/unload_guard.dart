import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_unload_guard.dart';

/// The browser's own "Leave site?" confirmation, for closing or refreshing
/// the tab while something on screen cannot be had again.
///
/// Behind an interface so nothing outside the platform files touches the
/// browser — and so no test does either.
abstract interface class UnloadGuard {
  /// Asks the browser to confirm before the page unloads. Registering twice
  /// is the same as once.
  void register();

  /// Lets the page unload without asking. Harmless when not registered.
  void unregister();
}

/// The platform's [UnloadGuard]: a `beforeunload` listener on the web, and
/// nothing on every other target. Overridden in tests with a fake.
final Provider<UnloadGuard> unloadGuardProvider = Provider<UnloadGuard>(
  (ref) => platformUnloadGuard(),
);
