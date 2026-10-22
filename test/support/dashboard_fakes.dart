import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/health/domain/health_repository.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission_repository.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation_repository.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';

/// A page holding [items] that says the collection holds [total].
Page<T> pageOf<T>(List<T> items, {int? total}) => Page<T>(
  items: items,
  pageNumber: 1,
  pageSize: items.isEmpty ? 1 : items.length,
  totalItems: total ?? items.length,
  totalPages: 1,
);

/// The repositories the home dashboard reads, answering with fixed figures.
///
/// Every scope holds [persons] Users, [applications] applications,
/// [permissions] permissions and [googleUsers] Google users. A `null` count
/// answers that listing with a failure instead.
class FakeDashboardRepositories {
  FakeDashboardRepositories({
    this.scopes = const <Scope>[],
    this.activeTotal,
    this.deletedScopes = 0,
    this.persons = 0,
    this.applications = 0,
    this.permissions = 0,
    this.googleUsers = 0,
    this.systemAdmins = 1,
    this.systemAdminsAnswer,
    this.scopesFailure,
    this.apiReachable = true,
    this.googleMe,
    this.invitations = const <ScopeInvitation>[],
    this.acceptHeldUntil,
    this.firstScopesReadHeldUntil,
    Person? me,
  }) : me =
           me ??
           const Person(
             id: 'me',
             name: 'Me',
             email: 'me@example.com',
             role: Role.systemAdmin,
           );

  final List<Scope> scopes;
  final int? activeTotal;
  final int deletedScopes;
  final int? persons;
  final int? applications;
  final int? permissions;
  final int? googleUsers;
  final int? systemAdmins;

  /// When set, answers the n-th System Admins read (from 1) instead of
  /// [systemAdmins], so a test can hold one read back.
  final Future<int?> Function(int read)? systemAdminsAnswer;
  final Failure? scopesFailure;
  final bool apiReachable;
  final Person me;

  /// The signed-in administrator's open invitations (UI-39).
  final List<ScopeInvitation> invitations;

  /// When set, an acceptance answers only once this completes, so a test can
  /// hold one back.
  final Future<void>? acceptHeldUntil;

  /// When set, the first scopes read answers only once this completes, so a
  /// test can hold a dashboard load back.
  final Future<void>? firstScopesReadHeldUntil;

  /// How many times the scopes listing was asked for; one dashboard load asks
  /// twice (the active page and the total with deleted ones).
  int scopeReads = 0;

  /// The invitation ids accepted and declined through the fakes, in order.
  final List<String> accepted = <String>[];
  final List<String> declined = <String>[];

  /// How many times the System Admins listing was asked for.
  int systemAdminsReads = 0;

  /// The signed-in Google User's own record, for a Google session. When set,
  /// the persons endpoint answers `404` for the caller, as the API does: a
  /// Google User is not a person.
  final GoogleUser? googleMe;

  List<Override> get overrides => <Override>[
    scopeRepositoryProvider.overrideWithValue(_Scopes(this)),
    personRepositoryProvider.overrideWithValue(_Persons(this)),
    applicationRepositoryProvider.overrideWithValue(_Applications(this)),
    scopePermissionRepositoryProvider.overrideWithValue(_Permissions(this)),
    googleUserRepositoryProvider.overrideWithValue(_GoogleUsers(this)),
    healthRepositoryProvider.overrideWithValue(_Health(this)),
    scopeInvitationRepositoryProvider.overrideWithValue(_Invitations(this)),
  ];
}

const Failure _unreadable = Failure(
  kind: FailureKind.server,
  errors: <String>['Unreadable'],
);

const Failure _notFound = Failure(
  kind: FailureKind.notFound,
  errors: <String>['Not found'],
);

Result<Page<T>> _count<T>(int? count) => count == null
    ? const FailureResult(_unreadable)
    : Success<Page<T>>(pageOf<T>(<T>[], total: count));

class _Scopes extends Fake implements ScopeRepository {
  _Scopes(this.fakes);

  final FakeDashboardRepositories fakes;

  @override
  Future<Result<Page<Scope>>> list({
    String? name,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    if (++fakes.scopeReads == 1 && fakes.firstScopesReadHeldUntil != null) {
      await fakes.firstScopesReadHeldUntil;
    }

    if (fakes.scopesFailure case final failure?) {
      return FailureResult<Page<Scope>>(failure);
    }

    final active = fakes.activeTotal ?? fakes.scopes.length;

    return Success<Page<Scope>>(
      pageOf<Scope>(
        fakes.scopes.take(pageSize).toList(),
        total: includeDeleted ? active + fakes.deletedScopes : active,
      ),
    );
  }
}

class _Persons extends Fake implements PersonRepository {
  _Persons(this.fakes);

  final FakeDashboardRepositories fakes;

  @override
  Future<Result<Person>> getById(
    String id, {
    bool includeDeleted = false,
  }) async => fakes.googleMe == null
      ? Success<Person>(fakes.me)
      : const FailureResult<Person>(_notFound);

  /// Takes any edit to the caller's own record, as the API answers one.
  @override
  Future<Result<Person>> update({
    required String id,
    required String name,
    required String email,
    int? roleId,
    String? currentPassword,
    String? twoFactorCode,
  }) async => Success<Person>(
    Person(
      id: fakes.me.id,
      name: name,
      email: email,
      role: fakes.me.role,
      emailVerified: email == fakes.me.email,
    ),
  );

  @override
  Future<Result<Page<PersonSummary>>> listSystemAdmins({
    String? name,
    String? email,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final read = ++fakes.systemAdminsReads;
    final answer = fakes.systemAdminsAnswer;

    return _count<PersonSummary>(
      answer == null ? fakes.systemAdmins : await answer(read),
    );
  }

  @override
  Future<Result<Page<Person>>> listScopePersons({
    required String scopeId,
    String? name,
    String? email,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async => _count<Person>(fakes.persons);
}

class _Applications extends Fake implements ApplicationRepository {
  _Applications(this.fakes);

  final FakeDashboardRepositories fakes;

  @override
  Future<Result<Page<Application>>> list({
    required String scopeId,
    String? name,
    String? ownerId,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async => _count<Application>(fakes.applications);
}

class _Permissions extends Fake implements ScopePermissionRepository {
  _Permissions(this.fakes);

  final FakeDashboardRepositories fakes;

  @override
  Future<Result<Page<ScopePermission>>> list({
    required String scopeId,
    String? name,
    bool includeDeleted = false,
    int pageNumber = 1,
    int pageSize = 20,
  }) async => _count<ScopePermission>(fakes.permissions);
}

class _GoogleUsers extends Fake implements GoogleUserRepository {
  _GoogleUsers(this.fakes);

  final FakeDashboardRepositories fakes;

  @override
  Future<Result<int>> countIn(String scopeId) async => fakes.googleUsers == null
      ? const FailureResult<int>(_unreadable)
      : Success<int>(fakes.googleUsers!);

  @override
  Future<Result<GoogleUser>> getById({
    required String scopeId,
    required String id,
    bool includeDeleted = true,
  }) async => switch (fakes.googleMe) {
    final GoogleUser me => Success<GoogleUser>(me),
    null => const FailureResult<GoogleUser>(_notFound),
  };
}

class _Health extends Fake implements HealthRepository {
  _Health(this.fakes);

  final FakeDashboardRepositories fakes;

  @override
  Future<Result<String>> ping() async => fakes.apiReachable
      ? const Success<String>('Healthy')
      : const FailureResult<String>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        );
}

class _Invitations extends Fake implements ScopeInvitationRepository {
  _Invitations(this.fakes);

  final FakeDashboardRepositories fakes;

  /// The open ones: an answered invitation is no longer listed, as the API
  /// would have it.
  @override
  Future<Result<Page<ScopeInvitation>>> listMine({
    int pageNumber = 1,
    int pageSize = 50,
  }) async => Success<Page<ScopeInvitation>>(
    pageOf<ScopeInvitation>(
      fakes.invitations
          .where(
            (invitation) =>
                !fakes.accepted.contains(invitation.id) &&
                !fakes.declined.contains(invitation.id),
          )
          .toList(),
    ),
  );

  @override
  Future<Result<void>> accept(String invitationId) async {
    if (fakes.acceptHeldUntil case final hold?) {
      await hold;
    }

    fakes.accepted.add(invitationId);

    return const Success<void>(null);
  }

  @override
  Future<Result<void>> decline(String invitationId) async {
    fakes.declined.add(invitationId);

    return const Success<void>(null);
  }
}
