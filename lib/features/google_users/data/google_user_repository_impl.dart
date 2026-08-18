import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/google_user.dart';
import '../domain/google_user_repository.dart';

/// [GoogleUserRepository] over the generated client.
class ApiGoogleUserRepository implements GoogleUserRepository {
  const ApiGoogleUserRepository(this._client);

  final GoogleUserClient _client;

  @override
  Future<Result<int>> countIn(String scopeId) async {
    try {
      final response = await _client.googleUserList(
        scopeId: scopeId,
        pageNumber: 1,
        // One item is enough: the count comes from the envelope's own total,
        // not from how many rows came back.
        pageSize: 1,
      );

      if (response.success != true) {
        return FailureResult<int>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return Success<int>(response.totalItems ?? response.data?.length ?? 0);
    } on DioException catch (error) {
      return FailureResult<int>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Page<GoogleUser>>> list({
    required String scopeId,
    String? name,
    String? email,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.googleUserList(
        scopeId: scopeId,
        // An empty filter is no filter: sending it would ask the API to match
        // the empty string rather than to stop filtering.
        name: _filter(name),
        email: _filter(email),
        includeDeleted: includeDeleted,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<GoogleUser>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <GoogleUserOutput>[])
          .map(googleUserFromOutput)
          .toList(growable: false);

      return Success<Page<GoogleUser>>(
        Page<GoogleUser>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      // AF-28b and AF-28c depend on this: a transport failure and a `403` are
      // different panels, and only the kind tells them apart.
      return FailureResult<Page<GoogleUser>>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<GoogleUser>> getById({
    required String scopeId,
    required String id,
    bool includeDeleted = true,
  }) async {
    try {
      final response = await _client.googleUserGetById(
        scopeId: scopeId,
        id: id,
        includeDeleted: includeDeleted,
      );

      if (response.success != true) {
        return FailureResult<GoogleUser>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<GoogleUser>(
          Failure(
            kind: FailureKind.unknown,
            errors: <String>['The API returned an incomplete response.'],
          ),
        );
      }

      return Success<GoogleUser>(googleUserFromOutput(data));
    } on DioException catch (error) {
      return FailureResult<GoogleUser>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> delete({
    required String scopeId,
    required String id,
  }) async {
    try {
      final response = await _client.googleUserDelete(scopeId: scopeId, id: id);

      // AF-29b: the API refuses a record it will not delete, and its own
      // strings say why.
      return _acknowledgement(response.success, response.errors);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> hardDelete({
    required String scopeId,
    required String id,
  }) async {
    try {
      final response = await _client.googleUserHardDelete(
        scopeId: scopeId,
        id: id,
      );

      return _acknowledgement(response.success, response.errors);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
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

  static String? _filter(String? value) =>
      (value?.trim().isEmpty ?? true) ? null : value!.trim();
}

/// Maps the generated output onto the domain entity.
GoogleUser googleUserFromOutput(GoogleUserOutput output) => GoogleUser(
  id: output.id ?? '',
  name: output.name ?? '',
  email: output.email ?? '',
  googleId: output.googleId,
  emailVerified: output.emailVerified ?? true,
  profilePictureUrl: output.profilePictureUrl,
  isDeleted: output.isDeleted ?? false,
  scopeId: output.scopeId,
  createdAt: output.createdAt,
  updatedAt: output.updatedAt,
);
