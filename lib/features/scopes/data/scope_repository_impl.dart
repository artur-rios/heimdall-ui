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
        return const FailureResult<Scope>(
          Failure(
            kind: FailureKind.unknown,
            errors: <String>['The API returned an incomplete response.'],
          ),
        );
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
}

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
