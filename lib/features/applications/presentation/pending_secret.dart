import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/unload/unload_guard.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';

/// Whether a credential's one-time secret is on its way or on screen. Only the
/// flag lives here, never the secret.
///
/// A route change (a browser Back, a redirect) removes the dialogs, and
/// `PopScope` does not catch it, so the application route asks before leaving
/// while this is set (ruling U21). Closing or refreshing the tab is no route
/// change, so while it is set the browser is asked to confirm that too.
class PendingSecret extends Notifier<bool> {
  @override
  bool build() {
    // The guard follows the flag here, beside it, so whatever sets or clears
    // the flag — the issue dialog, the card, a confirmed leave — moves the
    // guard with it, and no screen has to remember to.
    final guard = ref.watch(unloadGuardProvider);
    var guarded = false;

    void follow(bool pending) {
      if (pending != guarded) {
        guarded = pending;
        pending ? guard.register() : guard.unregister();
      }
    }

    listenSelf((previous, next) => follow(next));
    // Dropping the flag drops its guard, so a tab is never left asking about
    // a secret that is gone.
    ref.onDispose(() => follow(false));

    return false;
  }

  void set() => state = true;

  void clear() {
    if (ref.mounted && state) {
      state = false;
    }
  }
}

final NotifierProvider<PendingSecret, bool> pendingSecretProvider =
    NotifierProvider<PendingSecret, bool>(PendingSecret.new);

/// `onExit` for the application route: with no secret pending it lets the user
/// go; otherwise it asks, and clears the flag only if they leave anyway.
Future<bool> confirmLeaveWithPendingSecret(
  BuildContext context,
  Ref ref,
) async {
  // A session redirect always wins: without a session the secret cannot be
  // used, and asking would strand the redirect behind a dialog.
  if (ref.read(sessionControllerProvider) is! Authenticated) {
    ref.read(pendingSecretProvider.notifier).clear();

    return true;
  }

  if (!ref.read(pendingSecretProvider)) {
    return true;
  }

  final leave = await showConfirm(
    context: context,
    title: 'Leave without the secret?',
    message:
        'The secret is shown only once. If you leave now, it cannot be shown '
        'again; revoke this credential and issue another.',
    confirmLabel: 'Leave',
    destructive: true,
  );

  if (leave) {
    ref.read(pendingSecretProvider.notifier).clear();
  }

  return leave;
}
