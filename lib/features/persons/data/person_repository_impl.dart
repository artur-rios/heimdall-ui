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

  @override
  Future<Result<Person>> createUser({
    required String scopeId,
    required String name,
    required String email,
    required String password,
  }) => _created(
    () => _client.personCreateUser(
      scopeId: scopeId,
      body: CreateUserCommand(name: name, email: email, password: password),
    ),
    name: name,
    email: email,
    fallbackRole: Role.user,
  );

  @override
  Future<Result<Person>> createAdmin({
    required String name,
    required String email,
    required String password,
    required Role role,
  }) => _created(
    () => _client.personCreateAdmin(
      body: CreateAdminCommand(
        name: name,
        email: email,
        password: password,
        role: role.value,
      ),
    ),
    name: name,
    email: email,
    fallbackRole: role,
  );

  /// Runs a person-creating command and maps its envelope.
  ///
  /// AF-17b and AF-17c both arrive as an unsuccessful envelope carrying the
  /// API's own strings — a registered address and a password its policy
  /// refuses are told apart by what it says, not by anything decided here.
  Future<Result<Person>> _created(
    Future<CreatePersonCommandOutputDataOutput> Function() send, {
    required String name,
    required String email,
    required Role fallbackRole,
  }) async {
    try {
      final response = await send();

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

      return Success<Person>(
        Person(
          id: data.id ?? '',
          name: data.name ?? name,
          email: data.email ?? email,
          role: roleFromValue(data.role ?? fallbackRole.value),
          // A person the API just created has not verified anything yet; the
          // verification email is on its way.
          emailVerified: data.emailVerified ?? false,
          scopeId: data.scopeId,
          createdAt: data.createdAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Person>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Page<Person>>> listScopeOwners({
    required String scopeId,
    String? name,
    String? email,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) => _listing(
    () => _client.personListScopeOwners(
      scopeId: scopeId,
      name: _filter(name),
      email: _filter(email),
      includeDeleted: includeDeleted,
      pageNumber: pageNumber,
      pageSize: pageSize,
    ),
    pageNumber: pageNumber,
    pageSize: pageSize,
  );

  @override
  Future<Result<Page<Person>>> listScopePersons({
    required String scopeId,
    String? name,
    String? email,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) => _listing(
    () => _client.personListScopePersons(
      scopeId: scopeId,
      name: _filter(name),
      email: _filter(email),
      includeDeleted: includeDeleted,
      pageNumber: pageNumber,
      pageSize: pageSize,
    ),
    pageNumber: pageNumber,
    pageSize: pageSize,
  );

  @override
  Future<Result<void>> addScopeOwner({
    required String scopeId,
    required String personId,
  }) async {
    try {
      final response = await _client.personAddScopeOwner(
        scopeId: scopeId,
        personId: personId,
      );

      // AF-14b and AF-14c: not a Scope Admin, and already an owner, both
      // arrive here in the API's own words.
      return _acknowledgement(response.success, response.errors);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Person>> createScopeOwner({
    required String scopeId,
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.personCreateScopeOwner(
        scopeId: scopeId,
        body: CreateScopeOwnerCommand(
          name: name,
          email: email,
          password: password,
        ),
      );

      if (response.success != true) {
        // AF-14d: a rejected name, address, or password.
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

      return Success<Person>(
        Person(
          id: data.id ?? '',
          name: data.name ?? name,
          email: data.email ?? email,
          role: roleFromValue(data.role ?? Role.scopeAdmin.value),
          emailVerified: data.emailVerified ?? false,
          scopeId: data.scopeId,
          createdAt: data.createdAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Person>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> removeScopeOwner({
    required String scopeId,
    required String personId,
  }) async {
    try {
      final response = await _client.personRemoveScopeOwner(
        scopeId: scopeId,
        personId: personId,
      );

      // AF-14a: a scope may not be left without an owner, and the API is the
      // only party that knows whether this removal would do that.
      return _acknowledgement(response.success, response.errors);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<void>> promoteScopeUser({
    required String scopeId,
    required String personId,
  }) async {
    try {
      final response = await _client.personPromoteScopeUser(
        scopeId: scopeId,
        personId: personId,
      );

      return _acknowledgement(response.success, response.errors);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }

  /// An empty filter is no filter: sending it would ask the API to match the
  /// empty string rather than to stop filtering.
  static String? _filter(String? value) =>
      (value?.trim().isEmpty ?? true) ? null : value!.trim();

  /// Runs a paginated person listing and maps its envelope.
  Future<Result<Page<Person>>> _listing(
    Future<PersonOutputPaginatedOutput> Function() send, {
    required int pageNumber,
    required int pageSize,
  }) async {
    try {
      final response = await send();

      if (response.success != true) {
        return FailureResult<Page<Person>>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final items = (response.data ?? const <PersonOutput>[])
          .map(personFromOutput)
          .toList(growable: false);

      return Success<Page<Person>>(
        Page<Person>(
          items: items,
          pageNumber: response.pageNumber ?? pageNumber,
          pageSize: response.pageSize ?? pageSize,
          totalItems: response.totalItems ?? items.length,
          totalPages: response.totalPages ?? 1,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Page<Person>>(failureFromDioException(error));
    }
  }

  /// A command whose only interesting answer is whether it worked.
  Result<void> _acknowledgement(bool? success, List<String>? errors) =>
      success == true
      ? const Success<void>(null)
      : FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: errors ?? const <String>[],
          ),
        );
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
