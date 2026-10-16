import 'package:heimdall_ui/core/secrets/screen_security.dart';
import 'package:heimdall_ui/core/secrets/secret_clipboard.dart';

/// A [SecretClipboard] that only remembers what it was asked to copy, so a
/// screen's test sees the secret without a real clipboard or a pending timer.
class RecordingSecretClipboard extends SecretClipboard {
  final List<String> copied = <String>[];

  @override
  Future<void> copy(String secret) async => copied.add(secret);
}

/// A [ScreenSecurity] that counts the holds instead of calling the platform.
class RecordingScreenSecurity extends ScreenSecurity {
  int held = 0;

  @override
  void hold() => held++;

  @override
  void release() => held--;
}
