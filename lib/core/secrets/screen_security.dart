import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const MethodChannel _channel = MethodChannel('heimdall_ui/screen_security');

/// Keeps the window out of screenshots, screen recordings and the recents
/// thumbnail while a secret is on screen.
///
/// Android only (`FLAG_SECURE`, set by `MainActivity`); on every other target
/// it does nothing. Holds are counted, so two secrets on screen at once do not
/// release the window when the first one leaves.
class ScreenSecurity {
  ScreenSecurity();

  int _holds = 0;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void hold() {
    _holds++;

    if (_holds == 1) {
      _apply(secure: true);
    }
  }

  void release() {
    if (_holds == 0) {
      return;
    }

    _holds--;

    if (_holds == 0) {
      _apply(secure: false);
    }
  }

  void _apply({required bool secure}) {
    if (!_supported) {
      return;
    }

    // Best effort: a failure here must never get in the way of the screen.
    _channel
        .invokeMethod<void>('setSecure', <String, Object>{'secure': secure})
        .catchError((Object _) {});
  }
}

final Provider<ScreenSecurity> screenSecurityProvider =
    Provider<ScreenSecurity>((ref) => ScreenSecurity());

/// Secures the window for as long as [child] is on screen.
class ScreenSecurityGuard extends ConsumerStatefulWidget {
  const ScreenSecurityGuard({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ScreenSecurityGuard> createState() =>
      _ScreenSecurityGuardState();
}

class _ScreenSecurityGuardState extends ConsumerState<ScreenSecurityGuard> {
  late final ScreenSecurity _security;

  @override
  void initState() {
    super.initState();
    _security = ref.read(screenSecurityProvider)..hold();
  }

  @override
  void dispose() {
    _security.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
