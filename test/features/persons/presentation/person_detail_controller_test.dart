import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/person_detail_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  scopeId: 'scope-1',
);

const _deleted = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  isDeleted: true,
);

void main() {
  late _MockPersonRepository repository;
  late ProviderContainer container;

  PersonDetailController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(personDetailControllerProvider('person-1').notifier);
  }

  PersonDetailState currentState() =>
      container.read(personDetailControllerProvider('person-1'));

  void answerGetWith(Result<Person> result) {
    when(
      () => repository.getById(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerUpdateWith(Result<Person> result) {
    when(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: any(named: 'roleId'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockPersonRepository();
  });

  test('GivenAPerson_WhenLoaded_ThenTheRecordIsShown', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PersonDetailLoaded).person.name, 'Ada');
  });

  // AF-18d — a deleted person must be readable, so the read includes them.
  test('GivenAPerson_WhenLoaded_ThenDeletedRecordsAreIncluded', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(
      () => repository.getById('person-1', includeDeleted: true),
    ).called(1);
  });

  // AF-18a — no such person.
  test('GivenAMissingPerson_WhenLoaded_ThenStateIsNotFound', () async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PersonDetailUnavailable).isNotFound, isTrue);
  });

  // AF-18b — the person is out of this role's reach.
  test('GivenAForbiddenPerson_WhenLoaded_ThenStateIsForbidden', () async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PersonDetailUnavailable).isForbidden, isTrue);
  });

  test('GivenAnEdit_WhenSaved_ThenTheNewValuesAreSent', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const Success<Person>(
        Person(
          id: 'person-1',
          name: 'Ada L',
          email: 'ada@example.com',
          role: Role.user,
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada L', email: 'ada@example.com');

    // Then
    verify(
      () => repository.update(
        id: 'person-1',
        name: 'Ada L',
        email: 'ada@example.com',
      ),
    ).called(1);
  });

  // AF-18e — the role is never part of what this screen sends.
  test('GivenAnEdit_WhenSaved_ThenNoRoleIsSent', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(const Success<Person>(_ada));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada L', email: 'ada@example.com');

    // Then
    final captured = verify(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: captureAny(named: 'roleId'),
      ),
    ).captured;
    expect(captured.single, isNull);
  });

  // AF-18c — a refusal keeps the record and carries the API's own errors.
  test('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreKept', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That email address is already registered.'],
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada', email: 'taken@example.com');

    // Then
    final state = currentState() as PersonDetailLoaded;
    expect(state.saveFailure?.errors, <String>[
      'That email address is already registered.',
    ]);
    expect(state.person.email, 'ada@example.com');
  });

  // AF-18d — a deleted person is read-only.
  test('GivenADeletedPerson_WhenLoaded_ThenTheyAreReadOnly', () async {
    // Given
    answerGetWith(const Success<Person>(_deleted));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as PersonDetailLoaded).isReadOnly, isTrue);
  });

  test('GivenADeletedPerson_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Person>(_deleted));
    answerUpdateWith(const Success<Person>(_deleted));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Anything', email: 'anything@example.com');

    // Then
    verifyNever(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: any(named: 'roleId'),
      ),
    );
  });

  test('GivenNoChange_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(const Success<Person>(_ada));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada', email: 'ada@example.com');

    // Then
    verifyNever(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: any(named: 'roleId'),
      ),
    );
  });

  test('GivenASavedPerson_WhenAcknowledged_ThenTheNoticeClears', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const Success<Person>(
        Person(
          id: 'person-1',
          name: 'Ada L',
          email: 'ada@example.com',
          role: Role.user,
        ),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();
    await controller.save(name: 'Ada L', email: 'ada@example.com');

    // When
    controller.acknowledgeSave();

    // Then
    expect((currentState() as PersonDetailLoaded).saved, isFalse);
  });
}
