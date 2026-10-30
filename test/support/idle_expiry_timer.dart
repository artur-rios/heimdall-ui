import 'dart:async';

/// A session expiry timer that never fires, for widget tests that hold a
/// session: a real timer would be left pending on the test's fake clock.
/// Override `sessionExpiryTimerProvider` with it; the expiry's own tests use
/// `Timer.new` instead.
Timer idleExpiryTimer(Duration delay, void Function() callback) => _IdleTimer();

class _IdleTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}
