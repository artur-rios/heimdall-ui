import 'package:dio/dio.dart';

import '../result/result.dart';

/// One page of a `PaginatedOutput<T>` response.
class Page<T> {
  const Page({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  final List<T> items;
  final int pageNumber;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  bool get hasNextPage => pageNumber < totalPages;
}

List<String> _errorsOf(Map<String, dynamic> json) =>
    (json['errors'] as List<dynamic>? ?? const <dynamic>[])
        .map((error) => error.toString())
        .toList(growable: false);

/// Unwraps a `DataOutput<T>` envelope into a [Result].
///
/// An envelope that reports failure carries the reason in `errors`; the HTTP
/// status is not consulted here, because the API answers unsuccessfully within
/// a 2xx often enough that the body is the reliable signal.
Result<T> unwrapData<T>(
  Map<String, dynamic> json,
  T Function(Object? data) parse,
) {
  if (json['success'] != true) {
    return FailureResult<T>(
      Failure(kind: FailureKind.validation, errors: _errorsOf(json)),
    );
  }

  return Success<T>(parse(json['data']));
}

/// Unwraps a `PaginatedOutput<T>` envelope into a [Result] carrying a [Page].
Result<Page<T>> unwrapPage<T>(
  Map<String, dynamic> json,
  T Function(Object? item) parse,
) {
  if (json['success'] != true) {
    return FailureResult<Page<T>>(
      Failure(kind: FailureKind.validation, errors: _errorsOf(json)),
    );
  }

  final data = json['data'] as List<dynamic>? ?? const <dynamic>[];

  return Success<Page<T>>(
    Page<T>(
      items: data.map(parse).toList(growable: false),
      pageNumber: json['pageNumber'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? data.length,
      totalItems: json['totalItems'] as int? ?? data.length,
      totalPages: json['totalPages'] as int? ?? 1,
    ),
  );
}

/// Maps a transport or HTTP failure onto the domain's [Failure] model.
Failure failureFromDioException(DioException error) {
  final response = error.response;

  if (response == null) {
    return Failure(
      kind: switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => FailureKind.network,
        _ => FailureKind.unknown,
      },
      errors: const <String>[],
      message: error.message,
    );
  }

  final body = response.data;
  final errors = body is Map<String, dynamic>
      ? _errorsOf(body)
      : const <String>[];

  return Failure(
    kind: switch (response.statusCode) {
      400 || 422 => FailureKind.validation,
      401 => FailureKind.unauthorized,
      403 => FailureKind.forbidden,
      404 => FailureKind.notFound,
      409 => FailureKind.conflict,
      final int status when status >= 500 => FailureKind.server,
      _ => FailureKind.unknown,
    },
    errors: errors,
  );
}
