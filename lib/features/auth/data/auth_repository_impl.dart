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
  }) async {
    try {
      final response = await _client.authVerifyTwoFactorAuth(
        body: VerifyTwoFactorAuthCommand(
          challengeToken: challengeToken,
          code: code,
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

      return Success<AuthToken>(AuthToken(value: token, expiresAt: expiresAt));
    } on DioException catch (error) {
      return FailureResult<AuthToken>(failureFromDioException(error));
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
      LoggedIn(AuthToken(value: token, expiresAt: expiresAt)),
    );
  }
}

/// A successful envelope that nonetheless lacks what the flow needs. It should
/// not happen; saying so plainly beats a null dereference if it ever does.
const Failure _incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);
