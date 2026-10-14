import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

class _MockGoogleSignInGateway extends Mock implements GoogleSignInGateway {}

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

/// A Google sign-in's token: its subject is the Google User, not a person, and
/// it names the scope the Google User belongs to.
String _googleJwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'google-1',
        'role': 3,
        'scopeId': 'scope-1',
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _grace = GoogleUser(
  id: 'google-1',
  name: 'Grace',
  email: 'grace@example.com',
  scopeId: 'scope-1',
);

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
);

void main() {
  late _MockPersonRepository repository;
  late _MockGoogleUserRepository googleUsers;
  late _MockGoogleSignInGateway google;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<ProfileController> controllerUnderTest({
    bool viaGoogle = false,
  }) async {
    await store.write(
      AuthToken(
        value: viaGoogle ? _googleJwt() : _jwt(),
        expiresAt: DateTime.utc(2030),
        viaGoogle: viaGoogle,
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
        googleUserRepositoryProvider.overrideWithValue(googleUsers),
        googleSignInGatewayProvider.overrideWithValue(google),
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

  void answerGoogleGetWith(Result<GoogleUser> result) {
    when(
      () => googleUsers.getById(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
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
    googleUsers = _MockGoogleUserRepository();
    google = _MockGoogleSignInGateway();
    when(() => google.signOut()).thenAnswer((_) async {});
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

  // A Google User is not a person: their own record is read from the Google
  // User endpoints (UC-27), in the scope the token names.
  test('GivenAGoogleSession_WhenLoaded_ThenTheGoogleRecordIsRead', () async {
    // Given
    answerGoogleGetWith(const Success<GoogleUser>(_grace));
    final controller = await controllerUnderTest(viaGoogle: true);

    // When
    await controller.load();

    // Then
    verify(
      () => googleUsers.getById(
        scopeId: 'scope-1',
        id: 'google-1',
        includeDeleted: false,
      ),
    ).called(1);
  });

  test('GivenAGoogleSession_WhenLoaded_ThenNoPersonIsAskedFor', () async {
    // Given
    answerGoogleGetWith(const Success<GoogleUser>(_grace));
    final controller = await controllerUnderTest(viaGoogle: true);

    // When
    await controller.load();

    // Then
    verifyNever(
      () => repository.getById(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    );
  });

  test('GivenAGoogleRecord_WhenLoaded_ThenStateIsGoogleLoaded', () async {
    // Given
    answerGoogleGetWith(const Success<GoogleUser>(_grace));
    final controller = await controllerUnderTest(viaGoogle: true);

    // When
    await controller.load();

    // Then
    final state = container.read(profileControllerProvider);
    expect((state as GoogleProfileLoaded).user.name, 'Grace');
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // AF-08e still holds: a 404 for the Google User's own record means the
  // account was deleted from under the session.
  test('GivenAMissingGoogleRecord_WhenLoaded_ThenTheSessionEnds', () async {
    // Given
    answerGoogleGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = await controllerUnderTest(viaGoogle: true);

    // When
    await controller.load();

    // Then
    final session = container.read(sessionControllerProvider);
    expect((session as Unauthenticated).sessionExpired, isTrue);
    final state = container.read(profileControllerProvider);
    expect((state as ProfileUnavailable).sessionEnded, isTrue);
  });

  test(
    'GivenAGoogleTransportFailure_WhenLoaded_ThenTheSessionSurvives',
    () async {
      // Given
      answerGoogleGetWith(
        const FailureResult<GoogleUser>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      final controller = await controllerUnderTest(viaGoogle: true);

      // When
      await controller.load();

      // Then
      final state = container.read(profileControllerProvider);
      expect((state as ProfileUnavailable).sessionEnded, isFalse);
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  test(
    'GivenAPasswordSession_WhenLoaded_ThenNoGoogleRecordIsAskedFor',
    () async {
      // Given
      answerGetWith(const Success<Person>(_ada));
      final controller = await controllerUnderTest();

      // When
      await controller.load();

      // Then
      verifyNever(
        () => googleUsers.getById(
          scopeId: any(named: 'scopeId'),
          id: any(named: 'id'),
          includeDeleted: any(named: 'includeDeleted'),
        ),
      );
      expect(container.read(profileControllerProvider), isA<ProfileLoaded>());
    },
  );
}
