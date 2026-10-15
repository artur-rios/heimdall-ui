import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The system clipboard, behind an interface so a test never touches it.
abstract interface class ClipboardAccess {
  Future<String?> read();

  Future<void> write(String value);
}

class _SystemClipboard implements ClipboardAccess {
  const _SystemClipboard();

  @override
  Future<String?> read() async => (await Clipboard.getData('text/plain'))?.text;

  @override
  Future<void> write(String value) =>
      Clipboard.setData(ClipboardData(text: value));
}

/// How long a copied secret may stay on the clipboard.
const Duration secretClipboardLifetime = Duration(seconds: 60);

/// Copies a secret — a credential secret, a setup key, recovery codes — and
/// takes it back off the clipboard after [lifetime], so it does not outlive its
/// use in a clipboard history or another application.
///
/// The clipboard is cleared only if it still holds the secret: something the
/// person copied since is theirs to keep.
class SecretClipboard {
  SecretClipboard({
    ClipboardAccess? clipboard,
    this.lifetime = secretClipboardLifetime,
  }) : _clipboard = clipboard ?? const _SystemClipboard();

  final ClipboardAccess _clipboard;
  final Duration lifetime;
  Timer? _timer;

  /// Puts [secret] on the clipboard and schedules its removal. A later copy
  /// restarts the delay.
  Future<void> copy(String secret) async {
    _timer?.cancel();
    await _clipboard.write(secret);
    _timer = Timer(lifetime, () => unawaited(_clearIfStill(secret)));
  }

  Future<void> _clearIfStill(String secret) async {
    try {
      if (await _clipboard.read() == secret) {
        await _clipboard.write('');
      }
    } on Object {
      // A clipboard that cannot be read (a browser tab out of focus, a
      // background app on a recent Android) cannot be cleared either; there is
      // nothing more to do.
    }
  }
}

/// The application's one [SecretClipboard], so the delay survives the screen
/// that started it.
final Provider<SecretClipboard> secretClipboardProvider =
    Provider<SecretClipboard>((ref) => SecretClipboard());
