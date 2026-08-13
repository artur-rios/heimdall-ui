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

  Future<Result<AuthToken>> verifySecondFactor({
    required String challengeToken,
    required String code,
  });
}
