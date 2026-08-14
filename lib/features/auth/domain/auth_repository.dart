import '../../../core/result/result.dart';
import '../../../core/storage/token_store.dart';

/// What a login attempt produced.
sealed class LoginOutcome {
  const LoginOutcome();
}

/// Credentials were enough on their own.
final class LoggedIn extends LoginOutcome {
  const LoggedIn(this.token);

  final AuthToken token;
}

/// Credentials were accepted, and a second factor is now required.
final class TwoFactorRequired extends LoginOutcome {
  const TwoFactorRequired({
    required this.challengeToken,
    required this.availableMethods,
  });

  final String challengeToken;
  final List<String> availableMethods;
}

/// The authentication operations the session depends on.
///
/// Implemented in `features/auth/data` over the generated client, and faked in
/// tests — which is why nothing here mentions a transport.
abstract interface class AuthRepository {
  Future<Result<LoginOutcome>> login({
    required String email,
    required String password,
  });

  /// Answers a login challenge.
  ///
  /// The API takes a generated code and a recovery code in separate fields, so
  /// [isRecoveryCode] decides which one [code] is sent as.
  Future<Result<AuthToken>> verifySecondFactor({
    required String challengeToken,
    required String code,
    bool isRecoveryCode,
  });

  /// Asks the API to mail a password reset link.
  ///
  /// Carries no result beyond success, deliberately: the API answers the same
  /// way whether or not the address belongs to anyone, so there is nothing here
  /// that could tell a caller which it was.
  Future<Result<void>> requestPasswordRecovery({required String email});

  /// Sets a new password from the token in a recovery link.
  ///
  /// The token is the only credential someone who has lost their password can
  /// present, so it travels in the body and is never stored.
  Future<Result<void>> resetPassword({
    required String token,
    required String newPassword,
  });
}
