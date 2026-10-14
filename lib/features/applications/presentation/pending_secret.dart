import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/confirm_dialog.dart';

/// Whether a credential's one-time secret is on its way or on screen. Only the
/// flag lives here, never the secret.
///
/// A route change (a browser Back, a redirect) removes the dialogs, and
/// `PopScope` does not catch it, so the application route asks before leaving
/// while this is set (ruling U21).
class PendingSecret extends Notifier<bool> {
  @override
  bool build() => false;

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
  );

  if (leave) {
    ref.read(pendingSecretProvider.notifier).clear();
  }

  return leave;
}
