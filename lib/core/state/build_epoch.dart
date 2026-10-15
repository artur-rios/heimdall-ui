import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells a notifier's builds apart, so that an answer to a request made under
/// one build is never written into the next.
///
/// Invalidating a provider — as the application root does with every
/// session-scoped one when a session ends — rebuilds it on the same notifier
/// instance, while a request it started may still be in flight. `ref.mounted`
/// stays true across that rebuild, so it cannot tell the late answer from a
/// current one, and once written the previous session's answer would be the
/// next session's first state.
///
/// [epoch] moves on whenever the build it was read under is torn down. A method
/// reads it before its first `await`, and checks [isCurrent] after every
/// `await` before it touches the state or the notifier's own fields.
mixin BuildEpoch<StateT> on Notifier<StateT> {
  int _epoch = 0;

  /// Ties the epoch to this build. Called first in `build()`.
  void startEpoch() => ref.onDispose(() => _epoch++);

  /// The build now running, to be read before an `await`.
  int get epoch => _epoch;

  /// Whether [epoch] is still the build now running.
  bool isCurrent(int epoch) => epoch == _epoch;
}
