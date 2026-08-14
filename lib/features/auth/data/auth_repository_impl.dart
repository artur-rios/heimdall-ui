import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';

/// [AuthRepository] over the generated client.
///
/// This is the only place in the authentication feature that knows the
/// generated types exist; everything above it works in terms of the domain.
class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._client);

  final AuthClient _client;

  @override
  Future<Result<LoginOutcome>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.authLogin(
        body: LoginCommand(email: email, password: password),
      );

      return _outcomeFrom(response);
    } on DioException catch (error) {
      return FailureResult<LoginOutcome>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<AuthToken>> verifySecondFactor({
    required String challengeToken,
    required String code,
    bool isRecoveryCode = false,
  }) async {
    try {
      final response = await _client.authVerifyTwoFactorAuth(
        // AF-02d: a recovery code travels in its own field. Sending it as the
        // generated code would have the API check it against the wrong secret.
        body: VerifyTwoFactorAuthCommand(
          challengeToken: challengeToken,
          code: isRecoveryCode ? null : code,
          recoveryCode: isRecoveryCode ? code : null,
        ),
      );

      if (response.success != true) {
        return FailureResult<AuthToken>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;
      final token = data?.token;
      final expiresAt = data?.expiresAt;

      if (token == null || expiresAt == null) {
        return const FailureResult<AuthToken>(_incompleteResponse);
      }

      return Success<AuthToken>(
        AuthToken(
          value: token,
          expiresAt: expiresAt,
          // AF-05e: the API reports this with the token. A response that omits
          // it is not saying the address is unverified.
          emailVerified: data?.emailVerified ?? true,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<AuthToken>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> requestPasswordRecovery({required String email}) async {
    try {
      final response = await _client.authPasswordRecovery(
        body: PasswordRecoveryCommand(email: email),
      );

      if (response.success != true) {
        return FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      // Nothing from the response is read beyond its success. The API answers
      // an unknown address exactly as it answers a known one, and reading any
      // further would only invite the interface to tell them apart.
      return const Success<void>(null);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _client.authResetPassword(
        body: ResetPasswordCommand(token: token, newPassword: newPassword),
      );

      if (response.success != true) {
        return FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return const Success<void>(null);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<List<String>>> verifyEmail({required String token}) async {
    try {
      final response = await _client.authVerifyEmail(
        body: VerifyEmailCommand(token: token),
      );

      if (response.success != true) {
        return FailureResult<List<String>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      // AF-05d: an address that was already verified answers successfully, so
      // the messages are carried up rather than flattened away — they are what
      // lets the screen say which of the two happened.
      return Success<List<String>>(response.messages ?? const <String>[]);
    } on DioException catch (error) {
      return FailureResult<List<String>>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> resendVerificationEmail() async {
    try {
      final response = await _client.authResendVerification();

      if (response.success != true) {
        return FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return const Success<void>(null);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<AuthToken>> signInWithGoogle({
    required String idToken,
    String? scopeId,
  }) async {
    try {
      final response = await _client.authGoogleSignIn(
        body: GoogleSignInCommand(idToken: idToken, scopeId: scopeId),
      );

      if (response.success != true) {
        return FailureResult<AuthToken>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;
      final token = data?.token;
      final expiresAt = data?.expiresAt;

      if (token == null || expiresAt == null) {
        return const FailureResult<AuthToken>(_incompleteResponse);
      }

      return Success<AuthToken>(
        AuthToken(
          value: token,
          expiresAt: expiresAt,
          viaGoogle: true,
          emailVerified: data?.emailVerified ?? true,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<AuthToken>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> signOutFromGoogle() async {
    try {
      final response = await _client.authGoogleSignOut();

      if (response.success != true) {
        return FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return const Success<void>(null);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  /// Reads a login response, which answers one of two ways: a usable token, or
  /// a challenge that must be answered before a session exists.
  Result<LoginOutcome> _outcomeFrom(LoginCommandOutputDataOutput response) {
    if (response.success != true) {
      return FailureResult<LoginOutcome>(
        Failure(
          kind: FailureKind.validation,
          errors: response.errors ?? const <String>[],
        ),
      );
    }

    final data = response.data;

    if (data == null) {
      return const FailureResult<LoginOutcome>(_incompleteResponse);
    }

    if (data.requiresTwoFactor ?? false) {
      final challengeToken = data.challengeToken;

      if (challengeToken == null) {
        return const FailureResult<LoginOutcome>(_incompleteResponse);
      }

      return Success<LoginOutcome>(
        TwoFactorRequired(
          challengeToken: challengeToken,
          availableMethods: data.availableMethods ?? const <String>[],
        ),
      );
    }

    final token = data.token;
    final expiresAt = data.expiresAt;

    if (token == null || expiresAt == null) {
      return const FailureResult<LoginOutcome>(_incompleteResponse);
    }

    return Success<LoginOutcome>(
      LoggedIn(
        AuthToken(
          value: token,
          expiresAt: expiresAt,
          emailVerified: data.emailVerified ?? true,
        ),
      ),
    );
  }
}

/// A successful envelope that nonetheless lacks what the flow needs. It should
/// not happen; saying so plainly beats a null dereference if it ever does.
const Failure _incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);
