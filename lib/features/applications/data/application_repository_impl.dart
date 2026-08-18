import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../domain/application.dart';
import '../domain/application_repository.dart';

/// [ApplicationRepository] over the generated client.
class ApiApplicationRepository implements ApplicationRepository {
  const ApiApplicationRepository(this._client);

  final ApplicationClient _client;

  @override
  Future<Result<Page<Application>>> list({
    required String scopeId,
    String? name,
    String? ownerId,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.applicationList(
        scopeId: scopeId,
        // An empty filter is no filter: sending it would ask the API to match
        // the empty string rather than to stop filtering.
        name: _filter(name),
        ownerId: _filter(ownerId),
        includeDeleted: includeDeleted,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      if (response.success != true) {
        return FailureResult<Page<Application>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <ApplicationOutput>[])
          .map(applicationFromOutput)
          .toList(growable: false);

      return Success<Page<Application>>(
        Page<Application>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      // AF-20b and AF-20c depend on this: a transport failure and a `403` are
      // different panels, and only the kind tells them apart.
      return FailureResult<Page<Application>>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Application>> create({
    required String scopeId,
    required String name,
    required String ownerId,
  }) async {
    try {
      final response = await _client.applicationCreate(
        scopeId: scopeId,
        body: CreateApplicationCommand(name: name, ownerId: ownerId),
      );

      if (response.success != true) {
        // AF-21b and AF-21c: a duplicate name and an owner who is not of this
        // scope both arrive here, told apart by the API's own strings.
        return FailureResult<Application>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Application>(_incompleteResponse);
      }

      return Success<Application>(
        Application(
          id: data.id ?? '',
          name: data.name ?? name,
          ownerId: data.ownerId ?? ownerId,
          scopeId: data.scopeId ?? scopeId,
          createdAt: data.createdAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Application>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Application>> getById({
    required String scopeId,
    required String id,
    bool includeDeleted = true,
  }) async {
    try {
      final response = await _client.applicationGetById(
        scopeId: scopeId,
        id: id,
        includeDeleted: includeDeleted,
      );

      if (response.success != true) {
        return FailureResult<Application>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Application>(_incompleteResponse);
      }

      return Success<Application>(applicationFromOutput(data));
    } on DioException catch (error) {
      // AF-22a and AF-22b depend on this: a `404` and a `403` are different
      // panels, and only the kind tells them apart.
      return FailureResult<Application>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Application>> update({
    required String scopeId,
    required String id,
    required String name,
    required String ownerId,
  }) async {
    try {
      final response = await _client.applicationUpdate(
        scopeId: scopeId,
        id: id,
        body: UpdateApplicationCommand(name: name, ownerId: ownerId),
      );

      if (response.success != true) {
        // AF-22c: a duplicate name, or an owner of another scope.
        return FailureResult<Application>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Application>(_incompleteResponse);
      }

      // The update endpoint answers with its own output type, which carries no
      // `isDeleted`: an application the API just updated is not a deleted one.
      return Success<Application>(
        Application(
          id: data.id ?? id,
          name: data.name ?? name,
          ownerId: data.ownerId ?? ownerId,
          scopeId: data.scopeId ?? scopeId,
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Application>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> delete({
    required String scopeId,
    required String id,
  }) async {
    try {
      final response = await _client.applicationDelete(
        scopeId: scopeId,
        id: id,
      );

      // AF-23b: the API refuses an application it will not delete, and its own
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
      final response = await _client.applicationHardDelete(
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

/// A successful envelope that nonetheless lacks what the flow needs. It should
/// not happen; saying so plainly beats a null dereference if it ever does.
const Failure _incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);

/// Maps the generated output onto the domain entity.
Application applicationFromOutput(ApplicationOutput output) => Application(
  id: output.id ?? '',
  name: output.name ?? '',
  ownerId: output.ownerId ?? '',
  scopeId: output.scopeId,
  isDeleted: output.isDeleted ?? false,
  createdAt: output.createdAt,
  updatedAt: output.updatedAt,
);
