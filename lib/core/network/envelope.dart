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

/// The API's canonical messages for a `401` that refuses a credential typed into
/// the request — a password or a second factor — rather than the bearer token.
///
/// The API answers both with the same status (its message-to-status maps put
/// `FactorInvalid`, `PasswordMismatch`, and `CredentialNotAccepted` on `401`,
/// next to the token refusals), so the message is the only thing that tells
/// "you mistyped it" from "your session is over". The first must leave the
/// session and a login challenge alone; only the second ends them.
const Set<String> credentialRejections = <String>{
  // TwoFactorMessages.FactorInvalid — a wrong code at sign-in (AF-02a), or
  // when disabling (AF-09d) or regenerating recovery codes.
  'The code or recovery code is missing, incorrect, or already used.',
  // TwoFactorMessages.PasswordMismatch — the password given to disable.
  'The current password is incorrect.',
  // ErasureMessages.CredentialNotAccepted — re-authentication for erasure.
  'The credential presented was not accepted.',
};

/// Whether [body] is an envelope refusing a credential the caller typed,
/// rather than the token the request was made under.
bool rejectsSubmittedCredential(Object? body) =>
    body is Map<String, dynamic> &&
    _errorsOf(body).any(credentialRejections.contains);

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
      // A mistyped password or code is a rejection of the input, which the
      // screen lets the person correct; it says nothing about the session.
      401 when rejectsSubmittedCredential(body) => FailureKind.validation,
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
