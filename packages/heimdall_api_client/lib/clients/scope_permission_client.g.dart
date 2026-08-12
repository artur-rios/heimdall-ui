// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scope_permission_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _ScopePermissionClient implements ScopePermissionClient {
  _ScopePermissionClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<CreateScopePermissionCommandOutputDataOutput> scopePermissionCreate({
    required String scopeId,
    CreateScopePermissionCommand? body,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    final _data = <String, dynamic>{};
    _data.addAll(body?.toJson() ?? <String, dynamic>{});
    final _options =
        _setStreamType<CreateScopePermissionCommandOutputDataOutput>(
          Options(method: 'POST', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${scopeId}/permissions',
                queryParameters: queryParameters,
                data: _data,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CreateScopePermissionCommandOutputDataOutput _value;
    try {
      _value = CreateScopePermissionCommandOutputDataOutput.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ScopePermissionOutputPaginatedOutput> scopePermissionList({
    required String scopeId,
    String? scopeIdFilter,
    String? name,
    bool? includeDeleted,
    String? actingPersonId,
    int? actingRole,
    int? pageNumber,
    int? pageSize,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'ScopeId': scopeIdFilter,
      r'Name': name,
      r'IncludeDeleted': includeDeleted,
      r'ActingPersonId': actingPersonId,
      r'ActingRole': actingRole,
      r'PageNumber': pageNumber,
      r'PageSize': pageSize,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<ScopePermissionOutputPaginatedOutput>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes/${scopeId}/permissions',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ScopePermissionOutputPaginatedOutput _value;
    try {
      _value = ScopePermissionOutputPaginatedOutput.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<ScopePermissionOutputDataOutput> scopePermissionGetById({
    required String scopeId,
    required String id,
    bool? includeDeleted = false,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'includeDeleted': includeDeleted,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<ScopePermissionOutputDataOutput>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/scopes/${scopeId}/permissions/${id}',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late ScopePermissionOutputDataOutput _value;
    try {
      _value = ScopePermissionOutputDataOutput.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<UpdateScopePermissionCommandOutputDataOutput> scopePermissionUpdate({
    required String scopeId,
    required String id,
    UpdateScopePermissionCommand? body,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    final _data = <String, dynamic>{};
    _data.addAll(body?.toJson() ?? <String, dynamic>{});
    final _options =
        _setStreamType<UpdateScopePermissionCommandOutputDataOutput>(
          Options(method: 'PUT', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${scopeId}/permissions/${id}',
                queryParameters: queryParameters,
                data: _data,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late UpdateScopePermissionCommandOutputDataOutput _value;
    try {
      _value = UpdateScopePermissionCommandOutputDataOutput.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<DeleteScopePermissionCommandOutputDataOutput> scopePermissionDelete({
    required String scopeId,
    required String id,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<DeleteScopePermissionCommandOutputDataOutput>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${scopeId}/permissions/${id}',
                queryParameters: queryParameters,
                data: _data,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late DeleteScopePermissionCommandOutputDataOutput _value;
    try {
      _value = DeleteScopePermissionCommandOutputDataOutput.fromJson(
        _result.data!,
      );
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<HardDeleteScopePermissionCommandOutputDataOutput>
  scopePermissionHardDelete({
    required String scopeId,
    required String id,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options =
        _setStreamType<HardDeleteScopePermissionCommandOutputDataOutput>(
          Options(method: 'DELETE', headers: _headers, extra: _extra)
              .compose(
                _dio.options,
                '/api/scopes/${scopeId}/permissions/${id}/hard',
                queryParameters: queryParameters,
                data: _data,
              )
              .copyWith(
                baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl),
              ),
        );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late HardDeleteScopePermissionCommandOutputDataOutput _value;
    try {
      _value = HardDeleteScopePermissionCommandOutputDataOutput.fromJson(
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
