import 'package:dio/dio.dart';
import 'package:heimdall_api_client/export.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import '../../auth/domain/session.dart';
import '../domain/person.dart';
import '../domain/person_repository.dart';

/// [PersonRepository] over the generated client.
///
/// This is the only place in the person feature that knows the generated types
/// exist; everything above it works in terms of the domain.
class ApiPersonRepository implements PersonRepository {
  const ApiPersonRepository(this._client);

  final PersonClient _client;

  @override
  Future<Result<Person>> getById(
    String id, {
    bool includeDeleted = false,
  }) async {
    try {
      final response = await _client.personGetById(
        id: id,
        includeDeleted: includeDeleted,
      );

      if (response.success != true) {
        return FailureResult<Person>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Person>(incompleteResponse);
      }

      return Success<Person>(personFromOutput(data));
    } on DioException catch (error) {
      // AF-08e depends on this: a `404` must arrive as notFound rather than as
      // a generic failure, because it is the one refusal that ends the session.
      return FailureResult<Person>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Person>> update({
    required String id,
    required String name,
    required String email,
    int? roleId,
  }) async {
    try {
      final response = await _client.personUpdate(
        id: id,
        body: UpdatePersonCommand(name: name, email: email, roleId: roleId),
      );

      if (response.success != true) {
        // AF-08b: the API's own strings travel up untouched, so the screen can
        // put them against the field they name.
        return FailureResult<Person>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Person>(incompleteResponse);
      }

      // The update endpoint answers with its own output type rather than
      // `PersonOutput`, and that type has no `isDeleted` — a person you just
      // updated is not a deleted one, so `false` is the fact, not a guess.
      return Success<Person>(
        Person(
          id: data.id ?? id,
          name: data.name ?? name,
          email: data.email ?? email,
          role: roleFromValue(data.role ?? Role.user.value),
          emailVerified: data.emailVerified ?? true,
          scopeId: data.scopeId,
          ownedScopeIds: data.ownedScopeIds ?? const <String>[],
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Person>(failureFromDioException(error));
    }
  }
}

/// Maps the generated output onto the domain entity.
///
/// Shared with the listings, which read the same shape out of a paginated
/// envelope.
Person personFromOutput(PersonOutput output) => Person(
  id: output.id ?? '',
  name: output.name ?? '',
  email: output.email ?? '',
  role: roleFromValue(output.role ?? Role.user.value),
  emailVerified: output.emailVerified ?? true,
  isDeleted: output.isDeleted ?? false,
  scopeId: output.scopeId,
  ownedScopeIds: output.ownedScopeIds ?? const <String>[],
  createdAt: output.createdAt,
  updatedAt: output.updatedAt,
);

/// A successful envelope that nonetheless lacks what the flow needs. It should
/// not happen; saying so plainly beats a null dereference if it ever does.
const Failure incompleteResponse = Failure(
  kind: FailureKind.unknown,
  errors: <String>['The API returned an incomplete response.'],
);
