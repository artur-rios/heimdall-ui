import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

/// A token naming the signed-in person, which is where the controller reads the
/// identifier it asks the API for.
String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'email': 'ada@example.com',
        'role': 3,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
);

void main() {
  late _MockPersonRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<ProfileController> controllerUnderTest() async {
    await store.write(AuthToken(value: _jwt(), expiresAt: DateTime.utc(2030)));

    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    return container.read(profileControllerProvider.notifier);
  }

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
    store = InMemoryTokenStore();
  });

  test('GivenASession_WhenLoaded_ThenTheOwnRecordIsRead', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    final controller = await controllerUnderTest();

    // When
    await controller.load();

    // Then
    verify(() => repository.getById('person-1')).called(1);
  });

  test('GivenAPersonResponse_WhenLoaded_ThenStateIsLoaded', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    final controller = await controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = container.read(profileControllerProvider);
    expect((state as ProfileLoaded).person.name, 'Ada');
  });

  test('GivenAChangedName_WhenSaved_ThenTheNewValuesAreSent', () async {
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
    final controller = await controllerUnderTest();
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

  // AF-08d — saving with nothing changed is a no-op.
  test('GivenNoChange_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(const Success<Person>(_ada));
    final controller = await controllerUnderTest();
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

  // AF-08b — a refusal keeps the record and carries the API's own errors.
  test('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreKept', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Email is already taken.'],
        ),
      ),
    );
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada', email: 'taken@example.com');

    // Then
    final state = container.read(profileControllerProvider) as ProfileLoaded;
    expect(state.saveFailure?.errors, <String>['Email is already taken.']);
  });

  test('GivenARejectedUpdate_WhenSaved_ThenTheSessionSurvives', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada', email: 'taken@example.com');

    // Then
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // AF-08c — the API marks a changed address unverified again.
  test('GivenAChangedEmail_WhenSaved_ThenTheChangeIsFlagged', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const Success<Person>(
        Person(
          id: 'person-1',
          name: 'Ada',
          email: 'new@example.com',
          role: Role.user,
          emailVerified: false,
        ),
      ),
    );
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada', email: 'new@example.com');

    // Then
    final state = container.read(profileControllerProvider) as ProfileLoaded;
    expect(state.emailChanged, isTrue);
  });

  test('GivenAnUnchangedEmail_WhenSaved_ThenNoChangeIsFlagged', () async {
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
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.save(name: 'Ada L', email: 'ada@example.com');

    // Then
    final state = container.read(profileControllerProvider) as ProfileLoaded;
    expect(state.emailChanged, isFalse);
  });

  // AF-08e — the record was deleted from under the session.
  test('GivenAMissingRecord_WhenLoaded_ThenTheSessionEnds', () async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = await controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  test('GivenAMissingRecord_WhenLoaded_ThenTheReasonIsStated', () async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = await controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = container.read(profileControllerProvider);
    expect((state as ProfileUnavailable).sessionEnded, isTrue);
  });

  test('GivenATransportFailure_WhenLoaded_ThenStateIsUnavailable', () async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = await controllerUnderTest();

    // When
    await controller.load();

    // Then
    final state = container.read(profileControllerProvider);
    expect((state as ProfileUnavailable).sessionEnded, isFalse);
  });

  test('GivenASavedRecord_WhenAcknowledged_ThenTheNoticeClears', () async {
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
    final controller = await controllerUnderTest();
    await controller.load();
    await controller.save(name: 'Ada L', email: 'ada@example.com');

    // When
    controller.acknowledgeSave();

    // Then
    final state = container.read(profileControllerProvider) as ProfileLoaded;
    expect(state.saved, isFalse);
  });
}
