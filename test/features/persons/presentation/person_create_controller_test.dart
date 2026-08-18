import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/person_create_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _created = Person(
  id: 'person-9',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  emailVerified: false,
);

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;

  PersonCreateController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(personCreateControllerProvider('scope-1').notifier);
  }

  PersonCreateState currentState() =>
      container.read(personCreateControllerProvider('scope-1'));

  void answerUserWith(Result<Person> result) {
    when(
      () => repository.createUser(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerAdminWith(Result<Person> result) {
    when(
      () => repository.createAdmin(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUpAll(() {
    // `any(named: 'role')` needs a value it can pass around without touching.
    registerFallbackValue(Role.user);
  });

  setUp(() {
    repository = _MockPersonRepository();
  });

  test('GivenTheUserRole_WhenCreated_ThenTheScopeEndpointIsUsed', () async {
    // Given
    answerUserWith(const Success<Person>(_created));
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'secret',
      role: Role.user,
    );

    // Then
    verify(
      () => repository.createUser(
        scopeId: 'scope-1',
        name: 'Ada',
        email: 'ada@example.com',
        password: 'secret',
      ),
    ).called(1);
  });

  test('GivenAnAdminRole_WhenCreated_ThenTheUnscopedEndpointIsUsed', () async {
    // Given
    answerAdminWith(const Success<Person>(_created));
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'secret',
      role: Role.scopeAdmin,
    );

    // Then
    verify(
      () => repository.createAdmin(
        name: 'Grace',
        email: 'grace@example.com',
        password: 'secret',
        role: Role.scopeAdmin,
      ),
    ).called(1);
  });

  test('GivenACreatedPerson_WhenCreated_ThenTheRecordIsReturned', () async {
    // Given
    answerUserWith(const Success<Person>(_created));
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'secret',
      role: Role.user,
    );

    // Then
    expect((currentState() as PersonCreated).person.id, 'person-9');
  });

  // AF-17b — the address is already registered.
  test('GivenARegisteredEmail_WhenCreated_ThenApiErrorsAreKept', () async {
    // Given
    answerUserWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That email address is already registered.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Ada',
      email: 'taken@example.com',
      password: 'secret',
      role: Role.user,
    );

    // Then
    expect((currentState() as PersonCreateRejected).failure.errors, <String>[
      'That email address is already registered.',
    ]);
  });

  // AF-17c — the password does not satisfy the API's policy.
  test('GivenARejectedPassword_WhenCreated_ThenApiErrorsAreKept', () async {
    // Given
    answerUserWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The password is too short.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'x',
      role: Role.user,
    );

    // Then
    expect((currentState() as PersonCreateRejected).failure.errors, <String>[
      'The password is too short.',
    ]);
  });

  // AF-17d — the API refuses a role the caller may not create.
  test('GivenARefusedRole_WhenCreated_ThenApiErrorsAreKept', () async {
    // Given
    answerAdminWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.forbidden,
          errors: <String>['Only a System Admin may create an administrator.'],
        ),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.create(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'secret',
      role: Role.systemAdmin,
    );

    // Then
    expect((currentState() as PersonCreateRejected).failure.errors, <String>[
      'Only a System Admin may create an administrator.',
    ]);
  });

  test('GivenARequestInFlight_WhenSubmittedAgain_ThenOnlyOneIsSent', () async {
    // Given
    final pending = Completer<Result<Person>>();
    when(
      () => repository.createUser(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();

    // When
    final first = controller.create(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'secret',
      role: Role.user,
    );
    final second = controller.create(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'secret',
      role: Role.user,
    );
    pending.complete(const Success<Person>(_created));
    await Future.wait<void>(<Future<void>>[first, second]);

    // Then
    verify(
      () => repository.createUser(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);
  });

  // AF-17d — a Scope Admin is not offered a role they cannot create.
  test('GivenAScopeAdmin_WhenRolesOffered_ThenOnlyUserIsAmongThem', () {
    // Given
    const principal = Principal(
      id: 'person-1',
      email: 'admin@example.com',
      role: Role.scopeAdmin,
    );

    // When
    final roles = creatableRolesFor(principal);

    // Then
    expect(roles, <Role>[Role.user]);
  });

  test('GivenASystemAdmin_WhenRolesOffered_ThenAllThreeAreAmongThem', () {
    // Given
    const principal = Principal(
      id: 'person-1',
      email: 'admin@example.com',
      role: Role.systemAdmin,
    );

    // When
    final roles = creatableRolesFor(principal);

    // Then
    expect(roles, <Role>[Role.user, Role.scopeAdmin, Role.systemAdmin]);
  });
}
