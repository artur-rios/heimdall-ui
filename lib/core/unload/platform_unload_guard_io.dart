import 'unload_guard.dart';

/// Nothing to guard: off the web there is no tab to close or refresh.
UnloadGuard platformUnloadGuard() => const _NoUnloadGuard();

class _NoUnloadGuard implements UnloadGuard {
  const _NoUnloadGuard();

  @override
  void register() {}

  @override
  void unregister() {}
}
