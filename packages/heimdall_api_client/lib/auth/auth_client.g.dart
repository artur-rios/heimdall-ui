// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _AuthClient extends AuthClient {
  _AuthClient._(this._dio, Dio _transport, {this.baseUrl, this.errorLogger})
    : super._(_transport);

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<LoginCommandOutputDataOutput$Response> authLogin({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required LoginCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options = _setStreamType<LoginCommandOutputDataOutput$Response>(
      Options(
            method: 'POST',
            headers: _headers,
            extra: _extra,
            contentType: 'application/json',
          )
          .compose(
            _dio.options,
            '/api/auth/login',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late LoginCommandOutputDataOutput$Response _value;
    try {
      _value = LoginCommandOutputDataOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PasswordRecoveryCommandOutputDataOutput$Response>
  authPasswordRecovery({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required PasswordRecoveryCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<PasswordRecoveryCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/password-recovery',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PasswordRecoveryCommandOutputDataOutput$Response _value;
    try {
      _value = PasswordRecoveryCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RegisterCommandOutputDataOutput$Response> authRegister({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required RegisterCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options = _setStreamType<RegisterCommandOutputDataOutput$Response>(
      Options(
            method: 'POST',
            headers: _headers,
            extra: _extra,
            contentType: 'application/json',
          )
          .compose(
            _dio.options,
            '/api/auth/register',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RegisterCommandOutputDataOutput$Response _value;
    try {
      _value = RegisterCommandOutputDataOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ResetPasswordCommandOutputDataOutput$Response> authResetPassword({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required ResetPasswordCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<ResetPasswordCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/password-reset',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ResetPasswordCommandOutputDataOutput$Response _value;
    try {
      _value = ResetPasswordCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<VerifyEmailCommandOutputDataOutput$Response> authVerifyEmail({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required VerifyEmailCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<VerifyEmailCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/verify-email',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late VerifyEmailCommandOutputDataOutput$Response _value;
    try {
      _value = VerifyEmailCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ResendVerificationEmailCommandOutputDataOutput$Response>
  authResendVerification({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<ResendVerificationEmailCommandOutputDataOutput$Response>(
          Options(method: 'POST', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/auth/resend-verification',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ResendVerificationEmailCommandOutputDataOutput$Response _value;
    try {
      _value = ResendVerificationEmailCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<GoogleSignInCommandOutputDataOutput$Response> authGoogleSignIn({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required GoogleSignInCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<GoogleSignInCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/google',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late GoogleSignInCommandOutputDataOutput$Response _value;
    try {
      _value = GoogleSignInCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<GoogleSignOutCommandOutputDataOutput$Response> authGoogleSignOut({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<GoogleSignOutCommandOutputDataOutput$Response>(
          Options(method: 'POST', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/auth/google/sign-out',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late GoogleSignOutCommandOutputDataOutput$Response _value;
    try {
      _value = GoogleSignOutCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<EnableTwoFactorAuthCommandOutputDataOutput$Response>
  authEnableTwoFactorAuth({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required EnableTwoFactorAuthCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<EnableTwoFactorAuthCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/2fa/enable',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late EnableTwoFactorAuthCommandOutputDataOutput$Response _value;
    try {
      _value = EnableTwoFactorAuthCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ConfirmTwoFactorAuthCommandOutputDataOutput$Response>
  authConfirmTwoFactorAuth({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required ConfirmTwoFactorAuthCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<ConfirmTwoFactorAuthCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/2fa/confirm',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ConfirmTwoFactorAuthCommandOutputDataOutput$Response _value;
    try {
      _value = ConfirmTwoFactorAuthCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<VerifyTwoFactorAuthCommandOutputDataOutput$Response>
  authVerifyTwoFactorAuth({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required VerifyTwoFactorAuthCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<VerifyTwoFactorAuthCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/2fa/verify',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late VerifyTwoFactorAuthCommandOutputDataOutput$Response _value;
    try {
      _value = VerifyTwoFactorAuthCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ResendTwoFactorChallengeCodeCommandOutputDataOutput$Response>
  authResendTwoFactorChallengeCode({
    Map<String, Object?> extra = const {
      "openapi.security": [],
      "openapi.securitySchemes": {},
    },
    CancelToken? cancelToken,
    Options? options,
    required ResendTwoFactorChallengeCodeCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<
          ResendTwoFactorChallengeCodeCommandOutputDataOutput$Response
        >(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/2fa/challenge/resend',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ResendTwoFactorChallengeCodeCommandOutputDataOutput$Response _value;
    try {
      _value =
          ResendTwoFactorChallengeCodeCommandOutputDataOutput$Response.fromJson(
            _result.data!,
          );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<DisableTwoFactorAuthCommandOutputDataOutput$Response>
  authDisableTwoFactorAuth({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required DisableTwoFactorAuthCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<DisableTwoFactorAuthCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/2fa/disable',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late DisableTwoFactorAuthCommandOutputDataOutput$Response _value;
    try {
      _value = DisableTwoFactorAuthCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RegenerateRecoveryCodesCommandOutputDataOutput$Response>
  authRegenerateRecoveryCodes({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required RegenerateRecoveryCodesCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<RegenerateRecoveryCodesCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/2fa/recovery-codes/regenerate',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RegenerateRecoveryCodesCommandOutputDataOutput$Response _value;
    try {
      _value = RegenerateRecoveryCodesCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<DataExportCommandOutputDataOutput$Response> authExportMyData({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<DataExportCommandOutputDataOutput$Response>(
      Options(method: 'POST', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/auth/data-export',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late DataExportCommandOutputDataOutput$Response _value;
    try {
      _value = DataExportCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RequestErasureCommandOutputDataOutput$Response> authRequestErasure({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required RequestErasureCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<RequestErasureCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/erasure-request',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RequestErasureCommandOutputDataOutput$Response _value;
    try {
      _value = RequestErasureCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RestrictProcessingCommandOutputDataOutput$Response>
  authRestrictProcessing({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required RestrictProcessingCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<RestrictProcessingCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/processing-restriction',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RestrictProcessingCommandOutputDataOutput$Response _value;
    try {
      _value = RestrictProcessingCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ReapplyErasuresCommandOutputDataOutput$Response> authReapplyErasures({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required ReapplyErasuresCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<ReapplyErasuresCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/erasure-reconciliation',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ReapplyErasuresCommandOutputDataOutput$Response _value;
    try {
      _value = ReapplyErasuresCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<LiftProcessingRestrictionCommandOutputDataOutput$Response>
  authLiftProcessingRestriction({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    required LiftProcessingRestrictionCommand body,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{
      r'Accept': 'application/json',
      r'Content-Type': 'application/json',
    };
    _headers.removeWhere((k, v) => v == null);
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options =
        _setStreamType<
          LiftProcessingRestrictionCommandOutputDataOutput$Response
        >(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/auth/processing-restriction/lift',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late LiftProcessingRestrictionCommandOutputDataOutput$Response _value;
    try {
      _value =
          LiftProcessingRestrictionCommandOutputDataOutput$Response.fromJson(
            _result.data!,
          );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ErasureRequestOutputPaginatedOutput$Response> authListErasureRequests({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
    bool? overdueOnly,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'OverdueOnly': overdueOnly,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<ErasureRequestOutputPaginatedOutput$Response>(
          Options(method: 'GET', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/auth/erasure-requests',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ErasureRequestOutputPaginatedOutput$Response _value;
    try {
      _value = ErasureRequestOutputPaginatedOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<TwoFactorStatusOutputDataOutput$Response> authGetTwoFactorStatus({
    Map<String, Object?> extra = const {
      "openapi.security": [
        {"Bearer": []},
      ],
      "openapi.securitySchemes": {
        "Bearer": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT",
          "description":
              "Paste the token returned by POST /api/auth/login. The 'Bearer ' prefix is added for you.",
        },
      },
    },
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<TwoFactorStatusOutputDataOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/auth/2fa',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late TwoFactorStatusOutputDataOutput$Response _value;
    try {
      _value = TwoFactorStatusOutputDataOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  RequestOptions _setStreamType<T>(RequestOptions requestOptions) {
    if (T != dynamic &&
        !(requestOptions.responseType == ResponseType.bytes ||
            requestOptions.responseType == ResponseType.stream)) {
      if (T == String) {
        requestOptions.responseType = ResponseType.plain;
      } else {
        requestOptions.responseType = ResponseType.json;
      }
    }
    return requestOptions;
  }

  String _combineBaseUrls(String dioBaseUrl, String? baseUrl) {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return dioBaseUrl;
    }

    final url = Uri.parse(baseUrl);

    if (url.isAbsolute) {
      return url.toString();
    }

    return Uri.parse(dioBaseUrl).resolveUri(url).toString();
  }
}

// dart format on
