import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/session_controller.dart';
import 'edit_mode.dart';

/// Which open screens hold an edit that is not yet saved, by the page their
/// route built.
///
/// A screen says whether it has unsaved changes through `AppShell`, which
/// registers the question here for as long as the screen is open. The route's
/// `onExit` ([confirmLeaveWithUnsavedChanges]) asks it before the screen is
/// let go, and signing out asks [any]: with routes nested, a screen with an
/// edit can sit under the one on top.
class UnsavedChanges {
  final Map<LocalKey, bool Function()> _screens = <LocalKey, bool Function()>{};

  void register(LocalKey page, bool Function() hasChanges) =>
      _screens[page] = hasChanges;

  /// Forgets [page], unless another screen has registered it since.
  void unregister(LocalKey page, bool Function() hasChanges) {
    if (_screens[page] == hasChanges) {
      _screens.remove(page);
    }
  }

  /// Whether the screen [page] built holds an unsaved edit.
  bool on(LocalKey page) => _screens[page]?.call() ?? false;

  /// Whether any open screen holds an unsaved edit.
  bool get any => _screens.values.any((hasChanges) => hasChanges());
}

final Provider<UnsavedChanges> unsavedChangesProvider =
    Provider<UnsavedChanges>((ref) => UnsavedChanges());

/// `onExit` for a route whose screen can hold an unsaved edit: asks "Discard
/// your changes?" before the screen is left, whichever way it is left — the
/// navigation, the back control, a system Back or a browser Back.
///
/// One route-level guard rather than a `PopScope` per screen, because on the
/// web a browser Back is a route change that no `PopScope` sees.
FutureOr<bool> confirmLeaveWithUnsavedChanges(
  BuildContext context,
  GoRouterState state,
) {
  final container = ProviderScope.containerOf(context, listen: false);

  // A session redirect always wins: without a session the edit could not be
  // saved, and asking would strand the redirect behind a dialog.
  if (container.read(sessionControllerProvider) is! Authenticated ||
      !container.read(unsavedChangesProvider).on(state.pageKey)) {
    return true;
  }

  return confirmDiscardChanges(context, hasChanges: true);
}
