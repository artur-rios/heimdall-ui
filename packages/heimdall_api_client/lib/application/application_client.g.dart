// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _ApplicationClient extends ApplicationClient {
  _ApplicationClient._(
    this._dio,
    Dio _transport, {
    this.baseUrl,
    this.errorLogger,
  }) : super._(_transport);

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<ApplicationOutputPaginatedOutput$Response> applicationList({
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
    required String scopeId,
    String? name,
    String? ownerId,
    bool? includeDeleted,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'Name': name,
      r'OwnerId': ownerId,
      r'IncludeDeleted': includeDeleted,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<ApplicationOutputPaginatedOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes/${_pathSegment(scopeId)}/applications',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ApplicationOutputPaginatedOutput$Response _value;
    try {
      _value = ApplicationOutputPaginatedOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CreateApplicationCommandOutputDataOutput$Response> applicationCreate({
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
    required String scopeId,
    required CreateApplicationCommand body,
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
        _setStreamType<CreateApplicationCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/applications',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CreateApplicationCommandOutputDataOutput$Response _value;
    try {
      _value = CreateApplicationCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ApplicationOutputDataOutput$Response> applicationGetById({
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
    required String scopeId,
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
    final _options = _setStreamType<ApplicationOutputDataOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes/${_pathSegment(scopeId)}/applications/${_pathSegment(id)}',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ApplicationOutputDataOutput$Response _value;
    try {
      _value = ApplicationOutputDataOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<UpdateApplicationCommandOutputDataOutput$Response> applicationUpdate({
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
    required String scopeId,
    required String id,
    required UpdateApplicationCommand body,
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
        _setStreamType<UpdateApplicationCommandOutputDataOutput$Response>(
          Options(
                method: 'PUT',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/applications/${_pathSegment(id)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late UpdateApplicationCommandOutputDataOutput$Response _value;
    try {
      _value = UpdateApplicationCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<DeleteApplicationCommandOutputDataOutput$Response> applicationDelete({
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
    required String scopeId,
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
        _setStreamType<DeleteApplicationCommandOutputDataOutput$Response>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/applications/${_pathSegment(id)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late DeleteApplicationCommandOutputDataOutput$Response _value;
    try {
      _value = DeleteApplicationCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<HardDeleteApplicationCommandOutputDataOutput$Response>
  applicationHardDelete({
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
    required String scopeId,
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
        _setStreamType<HardDeleteApplicationCommandOutputDataOutput$Response>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/applications/${_pathSegment(id)}/hard',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late HardDeleteApplicationCommandOutputDataOutput$Response _value;
    try {
      _value = HardDeleteApplicationCommandOutputDataOutput$Response.fromJson(
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
