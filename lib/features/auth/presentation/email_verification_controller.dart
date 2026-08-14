import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import 'session_controller.dart';

/// How far the verification of a token has got.
sealed class VerifyStatus {
  const VerifyStatus();
}

/// Nothing is being verified — normally because the link carried no token
/// (AF-05a), which is a state rather than an error.
final class VerifyIdle extends VerifyStatus {
  const VerifyIdle();
}

/// The token is being checked. UI-05 verifies on open, so this is what the
/// screen shows first.
final class Verifying extends VerifyStatus {
  const Verifying();
}

/// The address is verified.
///
/// [messages] is the envelope's own wording, which is the only thing that
/// distinguishes a freshly verified address from one that already was
/// (AF-05d). Both are successes, and both land here.
final class Verified extends VerifyStatus {
  const Verified(this.messages);

  final List<String> messages;
}

/// AF-05b — the API refused the token.
final class VerifyRejected extends VerifyStatus {
  const VerifyRejected(this.failure);

  final Failure failure;
}

/// How far a request for a fresh verification email has got.
sealed class ResendStatus {
  const ResendStatus();
}

final class ResendIdle extends ResendStatus {
  const ResendIdle();
}

final class Resending extends ResendStatus {
  const Resending();
}

/// AF-05c — the API accepted the request. Neutral by design: it says an email
/// is on its way, not who it went to.
final class ResendSent extends ResendStatus {
  const ResendSent();
}

final class ResendRejected extends ResendStatus {
  const ResendRejected(this.failure);

  final Failure failure;
}

/// The two halves of UI-05, which run independently: a resend can follow a
/// rejected verification, and the banner resends with nothing to verify.
class EmailVerificationState {
  const EmailVerificationState({
    this.verification = const VerifyIdle(),
    this.resend = const ResendIdle(),
  });

  final VerifyStatus verification;
  final ResendStatus resend;

  EmailVerificationState copyWith({
    VerifyStatus? verification,
    ResendStatus? resend,
  }) => EmailVerificationState(
    verification: verification ?? this.verification,
    resend: resend ?? this.resend,
  );
}

final NotifierProvider<EmailVerificationController, EmailVerificationState>
emailVerificationControllerProvider =
    NotifierProvider<EmailVerificationController, EmailVerificationState>(
      EmailVerificationController.new,
    );

/// Owns email verification and the resend that backs it up.
class EmailVerificationController extends Notifier<EmailVerificationState> {
  @override
  EmailVerificationState build() => const EmailVerificationState();

  /// Verifies [token], which the screen calls as soon as it opens.
  ///
  /// AF-05a: a link with no token leaves the state idle and sends nothing —
  /// there is no request that could succeed.
  Future<void> verify(String? token) async {
    if (token == null || token.isEmpty) {
      state = state.copyWith(verification: const VerifyIdle());

      return;
    }

    if (state.verification is Verifying) {
      return;
    }

    state = state.copyWith(verification: const Verifying());

    final result = await ref
        .read(authRepositoryProvider)
        .verifyEmail(token: token);

    state = state.copyWith(
      verification: result.fold(
        onSuccess: Verified.new,
        onFailure: VerifyRejected.new,
      ),
    );
  }

  /// AF-05c — asks the API to send a fresh verification email.
  Future<void> resend() async {
    if (state.resend is Resending) {
      return;
    }

    state = state.copyWith(resend: const Resending());

    final result = await ref
        .read(authRepositoryProvider)
        .resendVerificationEmail();

    state = state.copyWith(
      resend: result.fold(
        onSuccess: (_) => const ResendSent(),
        onFailure: ResendRejected.new,
      ),
    );
  }
}
