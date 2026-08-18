import '../../../core/result/result.dart';
import '../../../core/storage/token_store.dart';
import 'two_factor.dart';

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

  /// Confirms an email address from the token in a verification link.
  ///
  /// Returns the envelope's `messages`, because an address that was already
  /// verified answers successfully too (AF-05d) and the wording is the only
  /// thing that tells the two apart.
  Future<Result<List<String>>> verifyEmail({required String token});

  /// Asks for a fresh verification email.
  ///
  /// Takes no argument: the API reads the person from the bearer token, so a
  /// caller can only ever ask for their own — and an anonymous caller cannot
  /// ask at all.
  Future<Result<void>> resendVerificationEmail();

  /// Exchanges a Google ID token for a Heimdall token.
  ///
  /// [scopeId] is the scope being entered, which the calling application named
  /// — the first exchange for a Google account in a scope creates the Google
  /// User, every later one authenticates it.
  Future<Result<AuthToken>> signInWithGoogle({
    required String idToken,
    String? scopeId,
  });

  /// Ends the caller's Google-authenticated session at the API. Takes no
  /// argument: the Google User is read from the bearer token.
  Future<Result<void>> signOutFromGoogle();

  /// Reads the caller's own two-factor configuration.
  ///
  /// Takes no argument for the same reason the rest of these do not: the API
  /// reads the person from the bearer token, so a caller can only ever ask
  /// about themselves. A caller who has never set it up is answered with every
  /// flag false; a Google User is refused, which is permanent rather than a
  /// fault.
  Future<Result<TwoFactorStatus>> twoFactorStatus();

  /// Starts enabling [method].
  ///
  /// An authenticator method comes back with an `otpAuthUri`; the email method
  /// comes back saying a code was sent.
  Future<Result<TwoFactorSetup>> enableTwoFactor(TwoFactorMethod method);

  /// Confirms a setup with the code the person received or generated.
  ///
  /// Returns the recovery codes, which the API issues exactly once — which is
  /// why AF-09c makes the screen refuse to leave until they are acknowledged.
  Future<Result<List<String>>> confirmTwoFactor({
    required TwoFactorMethod method,
    required String code,
  });

  /// Turns two-factor authentication off.
  ///
  /// The API accepts any one of a password, a generated code, or a recovery
  /// code as the credential; whichever the person supplied is the one sent.
  Future<Result<void>> disableTwoFactor({
    String? password,
    String? code,
    String? recoveryCode,
  });

  /// Issues a fresh set of recovery codes, invalidating the current ones.
  Future<Result<List<String>>> regenerateRecoveryCodes({
    String? code,
    String? recoveryCode,
  });
}
