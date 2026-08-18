import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/scope_permission.dart';
import '../domain/scope_permission_repository.dart';

/// [ScopePermissionRepository] over the generated client.
class ApiScopePermissionRepository implements ScopePermissionRepository {
  const ApiScopePermissionRepository(this._client);

  final ScopePermissionClient _client;

  @override
  Future<Result<Page<ScopePermission>>> list({
    required String scopeId,
    String? name,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.scopePermissionList(
        scopeId: scopeId,
        // An empty filter is no filter: sending it would ask the API to match
        // the empty string rather than to stop filtering.
        name: (name?.trim().isEmpty ?? true) ? null : name!.trim(),
        includeDeleted: includeDeleted,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<ScopePermission>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <ScopePermissionOutput>[])
          .map(scopePermissionFromOutput)
          .toList(growable: false);

      return Success<Page<ScopePermission>>(
        Page<ScopePermission>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      // AF-24b and AF-24c depend on this: a transport failure and a `403` are
      // different panels, and only the kind tells them apart.
      return FailureResult<Page<ScopePermission>>(
        failureFromDioException(error),
      );
    }
  }

  @override
  Future<Result<ScopePermission>> create({
    required String scopeId,
    required String name,
    required String description,
    required bool includeAsJwtClaim,
  }) async {
    try {
      final response = await _client.scopePermissionCreate(
        scopeId: scopeId,
        body: CreateScopePermissionCommand(
          name: name,
          description: description,
          includeAsJwtClaim: includeAsJwtClaim,
        ),
      );

      if (response.success != true) {
        // AF-25b: a name already used in this scope, in the API's own words.
        return FailureResult<ScopePermission>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<ScopePermission>(_incompleteResponse);
      }

      return Success<ScopePermission>(
        ScopePermission(
          id: data.id ?? '',
          name: data.name ?? name,
          description: data.description ?? description,
          includeAsJwtClaim: data.includeAsJwtClaim ?? includeAsJwtClaim,
          scopeId: data.scopeId ?? scopeId,
          createdAt: data.createdAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<ScopePermission>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<ScopePermission>> getById({
    required String scopeId,
    required String id,
    bool includeDeleted = true,
  }) async {
    try {
      final response = await _client.scopePermissionGetById(
        scopeId: scopeId,
        id: id,
        includeDeleted: includeDeleted,
      );

      if (response.success != true) {
        return FailureResult<ScopePermission>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<ScopePermission>(_incompleteResponse);
      }

      return Success<ScopePermission>(scopePermissionFromOutput(data));
    } on DioException catch (error) {
      // AF-26a and AF-26b depend on this: a `404` and a `403` are different
      // panels, and only the kind tells them apart.
      return FailureResult<ScopePermission>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<ScopePermission>> update({
    required String scopeId,
    required String id,
    required String name,
    required String description,
    required bool includeAsJwtClaim,
  }) async {
    try {
      final response = await _client.scopePermissionUpdate(
        scopeId: scopeId,
        id: id,
        body: UpdateScopePermissionCommand(
          name: name,
          description: description,
          includeAsJwtClaim: includeAsJwtClaim,
        ),
      );

      if (response.success != true) {
        // AF-26c: a duplicate name, in the API's own words.
        return FailureResult<ScopePermission>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<ScopePermission>(_incompleteResponse);
      }

      // The update endpoint answers with its own output type, which carries no
      // `isDeleted`: a permission the API just updated is not a deleted one.
      return Success<ScopePermission>(
        ScopePermission(
          id: data.id ?? id,
          name: data.name ?? name,
          description: data.description ?? description,
          includeAsJwtClaim: data.includeAsJwtClaim ?? includeAsJwtClaim,
          scopeId: data.scopeId ?? scopeId,
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<ScopePermission>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> delete({
    required String scopeId,
    required String id,
  }) async {
    try {
      final response = await _client.scopePermissionDelete(
        scopeId: scopeId,
        id: id,
      );

      // AF-27b: the API refuses a permission it will not delete, and its own
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
      final response = await _client.scopePermissionHardDelete(
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
}

/// A successful envelope that nonetheless lacks what the flow needs. It should
/// not happen; saying so plainly beats a null dereference if it ever does.
const Failure _incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);

/// Maps the generated output onto the domain entity.
ScopePermission scopePermissionFromOutput(ScopePermissionOutput output) =>
    ScopePermission(
      id: output.id ?? '',
      name: output.name ?? '',
      description: output.description ?? '',
      includeAsJwtClaim: output.includeAsJwtClaim ?? false,
      scopeId: output.scopeId,
      isDeleted: output.isDeleted ?? false,
      createdAt: output.createdAt,
      updatedAt: output.updatedAt,
    );
