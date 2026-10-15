import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

/// Copies a secret — a credential secret, a setup key, recovery codes — and,
/// where the platform allows, takes it back off the clipboard after [lifetime],
/// so it does not outlive its use in a clipboard history or another application.
///
/// This is best effort. The clipboard is cleared only if it still holds the
/// secret: something the person copied since is theirs to keep. A background
/// app on a recent Android cannot read the clipboard, so the check runs again
/// when the app comes back to the foreground past the deadline; if the read is
/// still refused, nothing is done. A browser tab reads the clipboard only after
/// a permission prompt, and a blind clear could wipe something else, so on the
/// web ([readable] false) the clipboard is never touched again after the copy.
/// Closing the app earlier leaves the secret where it is.
class SecretClipboard with WidgetsBindingObserver {
  SecretClipboard({
    ClipboardAccess? clipboard,
    this.lifetime = secretClipboardLifetime,
    bool? readable,
    DateTime Function()? now,
  }) : _clipboard = clipboard ?? const _SystemClipboard(),
       _readable = readable ?? !kIsWeb,
       _now = now ?? DateTime.now;

  final ClipboardAccess _clipboard;
  final Duration lifetime;
  final bool _readable;
  final DateTime Function() _now;
  Timer? _timer;
  String? _pending;
  DateTime? _deadline;
  bool _observing = false;

  /// Puts [secret] on the clipboard and schedules its removal. A later copy
  /// restarts the delay.
  Future<void> copy(String secret) async {
    _forget();
    await _clipboard.write(secret);

    if (!_readable) {
      return;
    }

    _pending = secret;
    _deadline = _now().add(lifetime);
    _timer = Timer(lifetime, () => unawaited(_clearIfStill()));
    _observe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final deadline = _deadline;

    if (state == AppLifecycleState.resumed &&
        deadline != null &&
        !_now().isBefore(deadline)) {
      unawaited(_clearIfStill());
    }
  }

  /// Drops any pending clear without touching the clipboard.
  void dispose() => _forget();

  void _observe() {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  void _forget() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _deadline = null;

    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  Future<void> _clearIfStill() async {
    final secret = _pending;

    _forget();

    if (secret == null) {
      return;
    }

    try {
      if (await _clipboard.read() == secret) {
        await _clipboard.write('');
      }
    } on Object {
      // A clipboard that cannot be read (a background app on a recent Android)
      // cannot be cleared safely either; there is nothing more to do.
    }
  }
}

/// The application's one [SecretClipboard], so the delay survives the screen
/// that started it.
final Provider<SecretClipboard> secretClipboardProvider =
    Provider<SecretClipboard>((ref) {
      final clipboard = SecretClipboard();
      ref.onDispose(clipboard.dispose);

      return clipboard;
    });
