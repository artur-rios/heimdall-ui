import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import 'session_controller.dart';

/// How far a password reset has got.
sealed class PasswordResetState {
  const PasswordResetState();
}

/// The form is waiting to be filled in.
final class ResetIdle extends PasswordResetState {
  const ResetIdle();
}

/// A reset is in flight; the submit control is disabled meanwhile.
final class ResetSubmitting extends PasswordResetState {
  const ResetSubmitting();
}

/// The password was changed. The screen offers sign-in from here.
final class ResetSucceeded extends PasswordResetState {
  const ResetSucceeded();
}

/// The API refused, or could not be reached.
///
/// AF-04b and AF-04d arrive here alike: the envelope names the reason in
/// `errors` but carries no code separating a spent token from a password the
/// policy rejects, so the screen shows what came back and offers a fresh link
/// rather than guessing which of the two it was.
final class ResetFailed extends PasswordResetState {
  const ResetFailed(this.failure);

  final Failure failure;
}

final NotifierProvider<PasswordResetController, PasswordResetState>
passwordResetControllerProvider =
    NotifierProvider<PasswordResetController, PasswordResetState>(
      PasswordResetController.new,
    );

/// Owns one password reset from submitted to answered.
class PasswordResetController extends Notifier<PasswordResetState> {
  @override
  PasswordResetState build() => const ResetIdle();

  /// Sets [newPassword] using the reset [token] from the link.
  ///
  /// A submission already in flight is not joined by a second one, so a double
  /// tap cannot spend the token twice.
  Future<void> submit({
    required String token,
    required String newPassword,
  }) async {
    if (state is ResetSubmitting) {
      return;
    }

    state = const ResetSubmitting();

    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(token: token, newPassword: newPassword);

    state = result.fold(
      onSuccess: (_) => const ResetSucceeded(),
      onFailure: ResetFailed.new,
    );
  }
}
