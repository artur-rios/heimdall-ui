import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/two_factor.dart';

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

  @override
  Future<Result<TwoFactorStatus>> twoFactorStatus() async {
    try {
      final response = await _client.authGetTwoFactorStatus();

      if (response.success != true) {
        return FailureResult<TwoFactorStatus>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<TwoFactorStatus>(_incompleteResponse);
      }

      return Success<TwoFactorStatus>(
        TwoFactorStatus(
          isActive: data.isActive ?? false,
          appEnabled: data.appEnabled ?? false,
          emailEnabled: data.emailEnabled ?? false,
          remainingRecoveryCodes: data.remainingRecoveryCodes ?? 0,
        ),
      );
    } on DioException catch (error) {
      // A Google User is refused permanently rather than transiently, and only
      // the kind tells the screen to say so instead of offering a retry.
      return FailureResult<TwoFactorStatus>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<TwoFactorSetup>> enableTwoFactor(TwoFactorMethod method) async {
    try {
      final response = await _client.authEnableTwoFactorAuth(
        body: EnableTwoFactorAuthCommand(methods: <String>[method.wireValue]),
      );

      if (response.success != true) {
        return FailureResult<TwoFactorSetup>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<TwoFactorSetup>(_incompleteResponse);
      }

      return Success<TwoFactorSetup>(
        TwoFactorSetup(
          method: method,
          otpAuthUri: data.otpAuthUri,
          emailCodeSent: data.emailCodeSent ?? false,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<TwoFactorSetup>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<List<String>>> confirmTwoFactor({
    required TwoFactorMethod method,
    required String code,
  }) async {
    try {
      final response = await _client.authConfirmTwoFactorAuth(
        // The command takes the two methods in separate fields, so which one
        // the code belongs to decides where it travels — sending it in the
        // wrong one would have the API check it against the wrong secret.
        body: ConfirmTwoFactorAuthCommand(
          appCode: method == TwoFactorMethod.app ? code : null,
          emailCode: method == TwoFactorMethod.email ? code : null,
        ),
      );

      if (response.success != true) {
        // AF-09a: the code was wrong. The setup is still alive at the API, so
        // this is a rejection of the code rather than of the attempt.
        return FailureResult<List<String>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return Success<List<String>>(
        response.data?.recoveryCodes ?? const <String>[],
      );
    } on DioException catch (error) {
      return FailureResult<List<String>>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> disableTwoFactor({
    String? password,
    String? code,
    String? recoveryCode,
  }) async {
    try {
      final response = await _client.authDisableTwoFactorAuth(
        body: DisableTwoFactorAuthCommand(
          password: password,
          code: code,
          recoveryCode: recoveryCode,
        ),
      );

      // AF-09d: the API rejected the credential, and its own strings say so.
      return _acknowledgement(response.success, response.errors);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<List<String>>> regenerateRecoveryCodes({
    String? code,
    String? recoveryCode,
  }) async {
    try {
      final response = await _client.authRegenerateRecoveryCodes(
        body: RegenerateRecoveryCodesCommand(
          code: code,
          recoveryCode: recoveryCode,
        ),
      );

      if (response.success != true) {
        return FailureResult<List<String>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return Success<List<String>>(
        response.data?.recoveryCodes ?? const <String>[],
      );
    } on DioException catch (error) {
      return FailureResult<List<String>>(failureFromDioException(error));
    }
  }

  /// A command whose only interesting answer is whether it worked.
  static Result<void> _acknowledgement(bool? success, List<String>? errors) =>
      success == true
      ? const Success<void>(null)
      : FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: errors ?? const <String>[],
          ),
        );

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
