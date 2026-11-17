// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _ScopeClient extends ScopeClient {
  _ScopeClient._(this._dio, Dio _transport, {this.baseUrl, this.errorLogger})
    : super._(_transport);

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<ScopeOutputPaginatedOutput$Response> scopeList({
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
    String? name,
    bool? includeDeleted,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'Name': name,
      r'IncludeDeleted': includeDeleted,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<ScopeOutputPaginatedOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ScopeOutputPaginatedOutput$Response _value;
    try {
      _value = ScopeOutputPaginatedOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CreateScopeCommandOutputDataOutput$Response> scopeCreate({
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
    required CreateScopeCommand body,
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
        _setStreamType<CreateScopeCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CreateScopeCommandOutputDataOutput$Response _value;
    try {
      _value = CreateScopeCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ScopeOutputDataOutput$Response> scopeGetById({
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
    required String id,
    bool? includeDeleted,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'includeDeleted': includeDeleted,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<ScopeOutputDataOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes/${_pathSegment(id)}',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ScopeOutputDataOutput$Response _value;
    try {
      _value = ScopeOutputDataOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<UpdateScopeCommandOutputDataOutput$Response> scopeUpdate({
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
    required String id,
    required UpdateScopeCommand body,
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
        _setStreamType<UpdateScopeCommandOutputDataOutput$Response>(
          Options(
                method: 'PUT',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late UpdateScopeCommandOutputDataOutput$Response _value;
    try {
      _value = UpdateScopeCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<DeleteScopeCommandOutputDataOutput$Response> scopeDelete({
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
    required String id,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<DeleteScopeCommandOutputDataOutput$Response>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late DeleteScopeCommandOutputDataOutput$Response _value;
    try {
      _value = DeleteScopeCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<HardDeleteScopeCommandOutputDataOutput$Response> scopeHardDelete({
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
    required String id,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<HardDeleteScopeCommandOutputDataOutput$Response>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}/hard',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late HardDeleteScopeCommandOutputDataOutput$Response _value;
    try {
      _value = HardDeleteScopeCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<SetGoogleSignInCommandOutputDataOutput$Response> scopeSetGoogleSignIn({
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
    required String id,
    required SetGoogleSignInCommand body,
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
        _setStreamType<SetGoogleSignInCommandOutputDataOutput$Response>(
          Options(
                method: 'PUT',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}/google-signin',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late SetGoogleSignInCommandOutputDataOutput$Response _value;
    try {
      _value = SetGoogleSignInCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<SetSelfRegistrationCommandOutputDataOutput$Response>
  scopeSetSelfRegistration({
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
    required String id,
    required SetSelfRegistrationCommand body,
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
        _setStreamType<SetSelfRegistrationCommandOutputDataOutput$Response>(
          Options(
                method: 'PUT',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}/self-registration',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late SetSelfRegistrationCommandOutputDataOutput$Response _value;
    try {
      _value = SetSelfRegistrationCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<SetScopeEmailLinksCommandOutputDataOutput$Response>
  scopeSetEmailLinks({
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
    required String id,
    required SetScopeEmailLinksCommand body,
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
        _setStreamType<SetScopeEmailLinksCommandOutputDataOutput$Response>(
          Options(
                method: 'PUT',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}/email-links',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late SetScopeEmailLinksCommandOutputDataOutput$Response _value;
    try {
      _value = SetScopeEmailLinksCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PendingRegistrationOutputPaginatedOutput$Response>
  scopeListPendingRegistrations({
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
    required String id,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<PendingRegistrationOutputPaginatedOutput$Response>(
          Options(method: 'GET', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}/pending-registrations',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PendingRegistrationOutputPaginatedOutput$Response _value;
    try {
      _value = PendingRegistrationOutputPaginatedOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<DiscardPendingRegistrationCommandOutputDataOutput$Response>
  scopeDiscardPendingRegistration({
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
    required String id,
    required String registrationId,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<
          DiscardPendingRegistrationCommandOutputDataOutput$Response
        >(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(id)}/pending-registrations/${_pathSegment(registrationId)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late DiscardPendingRegistrationCommandOutputDataOutput$Response _value;
    try {
      _value =
          DiscardPendingRegistrationCommandOutputDataOutput$Response.fromJson(
            _result.data!,
          );
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

/// A path parameter as one percent-encoded segment.
///
/// Added by tool/generate_api_client.dart. `.`, `..` and the empty string
/// cannot be one segment of a URI at all, since the URI would drop or climb a
/// segment, so they are refused before anything is sent.
String _pathSegment(String value) {
  if (value.isEmpty || value == '.' || value == '..') {
    throw ArgumentError.value(value, 'value', 'is not a path segment');
  }

  return Uri.encodeComponent(value);
}
