// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _PersonClient extends PersonClient {
  _PersonClient._(this._dio, Dio _transport, {this.baseUrl, this.errorLogger})
    : super._(_transport);

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<CreatePersonCommandOutputDataOutput$Response> personCreateAdmin({
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
    required CreateAdminCommand body,
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
        _setStreamType<CreatePersonCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/persons',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CreatePersonCommandOutputDataOutput$Response _value;
    try {
      _value = CreatePersonCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PersonOutputPaginatedOutput$Response> personListScopePersons({
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
    String? email,
    bool? includeDeleted,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'Name': name,
      r'Email': email,
      r'IncludeDeleted': includeDeleted,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<PersonOutputPaginatedOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes/${_pathSegment(scopeId)}/persons',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PersonOutputPaginatedOutput$Response _value;
    try {
      _value = PersonOutputPaginatedOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CreatePersonCommandOutputDataOutput$Response> personCreateUser({
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
    required CreateUserCommand body,
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
        _setStreamType<CreatePersonCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/persons',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CreatePersonCommandOutputDataOutput$Response _value;
    try {
      _value = CreatePersonCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PersonOutputPaginatedOutput$Response> personListScopeOwners({
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
    String? email,
    bool? includeDeleted,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'Name': name,
      r'Email': email,
      r'IncludeDeleted': includeDeleted,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<PersonOutputPaginatedOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes/${_pathSegment(scopeId)}/owners',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PersonOutputPaginatedOutput$Response _value;
    try {
      _value = PersonOutputPaginatedOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CreatePersonCommandOutputDataOutput$Response> personCreateScopeOwner({
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
    required CreateScopeOwnerCommand body,
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
        _setStreamType<CreatePersonCommandOutputDataOutput$Response>(
          Options(
                method: 'POST',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/owners',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CreatePersonCommandOutputDataOutput$Response _value;
    try {
      _value = CreatePersonCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<AddScopeOwnerCommandOutputDataOutput$Response> personAddScopeOwner({
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
    required String personId,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<AddScopeOwnerCommandOutputDataOutput$Response>(
          Options(method: 'POST', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/owners/${_pathSegment(personId)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late AddScopeOwnerCommandOutputDataOutput$Response _value;
    try {
      _value = AddScopeOwnerCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RemoveScopeOwnerCommandOutputDataOutput$Response>
  personRemoveScopeOwner({
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
    required String personId,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<RemoveScopeOwnerCommandOutputDataOutput$Response>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/owners/${_pathSegment(personId)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RemoveScopeOwnerCommandOutputDataOutput$Response _value;
    try {
      _value = RemoveScopeOwnerCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PromoteScopeUserCommandOutputDataOutput$Response>
  personPromoteScopeUser({
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
    required String personId,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<PromoteScopeUserCommandOutputDataOutput$Response>(
          Options(method: 'POST', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${_pathSegment(scopeId)}/users/${_pathSegment(personId)}/promote',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PromoteScopeUserCommandOutputDataOutput$Response _value;
    try {
      _value = PromoteScopeUserCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PersonOutputDataOutput$Response> personGetById({
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
    final _options = _setStreamType<PersonOutputDataOutput$Response>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/persons/${_pathSegment(id)}',
            queryParameters: queryParameters,
            data: _data,
            cancelToken: cancelToken,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PersonOutputDataOutput$Response _value;
    try {
      _value = PersonOutputDataOutput$Response.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<UpdatePersonCommandOutputDataOutput$Response> personUpdate({
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
    required UpdatePersonCommand body,
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
        _setStreamType<UpdatePersonCommandOutputDataOutput$Response>(
          Options(
                method: 'PUT',
                headers: _headers,
                extra: _extra,
                contentType: 'application/json',
              )
              .compose(
                _dio.options,
                '/api/persons/${_pathSegment(id)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late UpdatePersonCommandOutputDataOutput$Response _value;
    try {
      _value = UpdatePersonCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<DeletePersonCommandOutputDataOutput$Response> personDelete({
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
        _setStreamType<DeletePersonCommandOutputDataOutput$Response>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/persons/${_pathSegment(id)}',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late DeletePersonCommandOutputDataOutput$Response _value;
    try {
      _value = DeletePersonCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<HardDeletePersonCommandOutputDataOutput$Response> personHardDelete({
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
        _setStreamType<HardDeletePersonCommandOutputDataOutput$Response>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/persons/${_pathSegment(id)}/hard',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late HardDeletePersonCommandOutputDataOutput$Response _value;
    try {
      _value = HardDeletePersonCommandOutputDataOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PersonSummaryOutputPaginatedOutput$Response> personListScopeAdmins({
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
    String? email,
    String? excludeOwnersOfScopeId,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'Name': name,
      r'Email': email,
      r'ExcludeOwnersOfScopeId': excludeOwnersOfScopeId,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<PersonSummaryOutputPaginatedOutput$Response>(
          Options(method: 'GET', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/persons/scope-admins',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PersonSummaryOutputPaginatedOutput$Response _value;
    try {
      _value = PersonSummaryOutputPaginatedOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<PersonSummaryOutputPaginatedOutput$Response> personListSystemAdmins({
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
    String? email,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    _extra.addAll(extra);
    final queryParameters = <String, dynamic>{
      r'Name': name,
      r'Email': email,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{r'Accept': 'application/json'};
    _headers.removeWhere((k, v) => v == null);
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<PersonSummaryOutputPaginatedOutput$Response>(
          Options(method: 'GET', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/persons/system-admins',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PersonSummaryOutputPaginatedOutput$Response _value;
    try {
      _value = PersonSummaryOutputPaginatedOutput$Response.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<SendPersonVerificationEmailCommandOutputDataOutput$Response>
  personSendVerificationEmail({
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
        _setStreamType<
          SendPersonVerificationEmailCommandOutputDataOutput$Response
        >(
          Options(method: 'POST', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/persons/${_pathSegment(id)}/verification-email',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late SendPersonVerificationEmailCommandOutputDataOutput$Response _value;
    try {
      _value =
          SendPersonVerificationEmailCommandOutputDataOutput$Response.fromJson(
            _result.data!,
          );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<SendPersonPasswordResetCommandOutputDataOutput$Response>
  personSendPasswordReset({
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
        _setStreamType<SendPersonPasswordResetCommandOutputDataOutput$Response>(
          Options(method: 'POST', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/persons/${_pathSegment(id)}/password-reset',
                queryParameters: queryParameters,
                data: _data,
                cancelToken: cancelToken,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late SendPersonPasswordResetCommandOutputDataOutput$Response _value;
    try {
      _value = SendPersonPasswordResetCommandOutputDataOutput$Response.fromJson(
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
