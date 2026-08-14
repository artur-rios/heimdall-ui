import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import 'session_controller.dart';

/// How far a password recovery request has got.
sealed class PasswordRecoveryState {
  const PasswordRecoveryState();
}

/// Nothing has been asked for yet.
final class RecoveryIdle extends PasswordRecoveryState {
  const RecoveryIdle();
}

/// A request is in flight. AF-03c: the screen refuses a second submission while
/// the session is in this state, so a double tap cannot send twice.
final class RecoverySending extends PasswordRecoveryState {
  const RecoverySending();
}

/// The API accepted the request. This says nothing about whether the address is
/// registered, and is shown identically either way.
final class RecoverySent extends PasswordRecoveryState {
  const RecoverySent();
}

/// The request did not reach the API, or the API refused it.
final class RecoveryFailed extends PasswordRecoveryState {
  const RecoveryFailed(this.failure);

  final Failure failure;
}

final NotifierProvider<PasswordRecoveryController, PasswordRecoveryState>
passwordRecoveryControllerProvider =
    NotifierProvider<PasswordRecoveryController, PasswordRecoveryState>(
      PasswordRecoveryController.new,
    );

/// Owns one password recovery request from asked to answered.
class PasswordRecoveryController extends Notifier<PasswordRecoveryState> {
  @override
  PasswordRecoveryState build() => const RecoveryIdle();

  /// Asks for a reset link for [email].
  ///
  /// AF-03c: a request already in flight is not joined by a second one. The
  /// guard lives here rather than only in the screen, so it holds however the
  /// submission was triggered.
  Future<void> request(String email) async {
    if (state is RecoverySending) {
      return;
    }

    state = const RecoverySending();

    final result = await ref
        .read(authRepositoryProvider)
        .requestPasswordRecovery(email: email);

    state = result.fold(
      onSuccess: (_) => const RecoverySent(),
      // AF-03b: nothing was sent, so the confirmation would be a lie. The
      // failure is kept as it came back and the screen decides how to say it.
      onFailure: RecoveryFailed.new,
    );
  }

  /// Returns the screen to its starting state, so a failed attempt can be made
  /// again against a corrected address.
  void reset() {
    state = const RecoveryIdle();
  }
}
