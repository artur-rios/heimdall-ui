import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/scope.dart';
import '../domain/scope_repository.dart';

/// [ScopeRepository] over the generated client.
///
/// This is the only place in the scope feature that knows the generated types
/// exist; everything above it works in terms of the domain.
class ApiScopeRepository implements ScopeRepository {
  const ApiScopeRepository(this._client);

  final ScopeClient _client;

  @override
  Future<Result<Page<Scope>>> list({
    String? name,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.scopeList(
        // An empty search is no search: sending it would ask the API to match
        // the empty string rather than to stop filtering.
        name: (name?.trim().isEmpty ?? true) ? null : name!.trim(),
        includeDeleted: includeDeleted,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<Scope>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <ScopeOutput>[])
          .map(scopeFromOutput)
          .toList(growable: false);

      return Success<Page<Scope>>(
        Page<Scope>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      // AF-10b: a transport failure keeps its own kind, which is what lets the
      // screen offer a retry rather than render the API's silence as an error.
      return FailureResult<Page<Scope>>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Scope>> create({
    required String name,
    required String description,
    required List<String> ownerIds,
  }) async {
    try {
      final response = await _client.scopeCreate(
        body: CreateScopeCommand(
          name: name,
          description: description,
          ownerIds: ownerIds,
        ),
      );

      if (response.success != true) {
        // AF-11b and AF-11c: a duplicate name and an owner who is not a Scope
        // Admin both arrive here, and both are told apart by the API's own
        // strings rather than by anything this layer decides.
        return FailureResult<Scope>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Scope>(_incompleteResponse);
      }

      // The create endpoint answers with its own output type, which carries no
      // `isDeleted`: a scope you just created is not a deleted one.
      return Success<Scope>(
        Scope(
          id: data.id ?? '',
          name: data.name ?? name,
          description: data.description ?? description,
          googleSignInEnabled: data.googleSignInEnabled ?? false,
          ownerIds: data.ownerIds ?? ownerIds,
          createdAt: data.createdAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Scope>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Scope>> getById(String id, {bool includeDeleted = true}) async {
    try {
      final response = await _client.scopeGetById(
        id: id,
        includeDeleted: includeDeleted,
      );

      if (response.success != true) {
        return FailureResult<Scope>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Scope>(_incompleteResponse);
      }

      return Success<Scope>(scopeFromOutput(data));
    } on DioException catch (error) {
      // AF-12a and AF-12b depend on this: a `404` and a `403` are different
      // panels, and only the kind tells them apart.
      return FailureResult<Scope>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Scope>> update({
    required String id,
    required String name,
    required String description,
  }) async {
    try {
      final response = await _client.scopeUpdate(
        id: id,
        body: UpdateScopeCommand(name: name, description: description),
      );

      if (response.success != true) {
        // AF-12c: a duplicate name arrives here, in the API's own words.
        return FailureResult<Scope>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Scope>(_incompleteResponse);
      }

      // The update endpoint answers with its own output type, which carries no
      // `isDeleted`: a scope the API just updated is not a deleted one.
      return Success<Scope>(
        Scope(
          id: data.id ?? id,
          name: data.name ?? name,
          description: data.description ?? description,
          googleSignInEnabled: data.googleSignInEnabled ?? false,
          ownerIds: data.ownerIds ?? const <String>[],
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Scope>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Scope>> setGoogleSignIn({
    required String id,
    required bool enabled,
  }) async {
    try {
      final response = await _client.scopeSetGoogleSignIn(
        id: id,
        body: SetGoogleSignInCommand(enabled: enabled),
      );

      if (response.success != true) {
        // AF-15a: the API refused, and its own strings say why.
        return FailureResult<Scope>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Scope>(_incompleteResponse);
      }

      return Success<Scope>(
        Scope(
          id: data.id ?? id,
          name: data.name ?? '',
          description: data.description ?? '',
          googleSignInEnabled: data.googleSignInEnabled ?? enabled,
          ownerIds: data.ownerIds ?? const <String>[],
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Scope>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final response = await _client.scopeDelete(id: id);

      return _deletionOutcome(response.success, response.errors);
    } on DioException catch (error) {
      // AF-13d: a `404` means somebody already deleted it, and the screen
      // treats that as done rather than as a failure — which it can only do
      // because the kind survives.
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> hardDelete(String id) async {
    try {
      final response = await _client.scopeHardDelete(id: id);

      return _deletionOutcome(response.success, response.errors);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  /// AF-13b: the API refuses a scope it will not delete — one that still holds
  /// users, for instance — and its own strings are what say why.
  Result<void> _deletionOutcome(bool? success, List<String>? errors) =>
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
Scope scopeFromOutput(ScopeOutput output) => Scope(
  id: output.id ?? '',
  name: output.name ?? '',
  description: output.description ?? '',
  googleSignInEnabled: output.googleSignInEnabled ?? false,
  isDeleted: output.isDeleted ?? false,
  ownerIds: output.ownerIds ?? const <String>[],
  createdAt: output.createdAt,
  updatedAt: output.updatedAt,
);
