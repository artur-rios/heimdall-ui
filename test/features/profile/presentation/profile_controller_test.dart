import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/domain/two_factor.dart';
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

class _MockAuthRepository extends Mock implements AuthRepository {}

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

/// Ada with a second factor on, which the API reports on her record.
const _adaWithTwoFactor = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  twoFactorEnabled: true,
);

/// What Ada's address becomes once a change to it is saved.
const _adaMoved = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'new@example.com',
  role: Role.user,
  emailVerified: false,
);

/// The API's answer to a wrong password (TwoFactorMessages.PasswordMismatch).
const _wrongPassword = Failure(
  kind: FailureKind.validation,
  errors: <String>['The current password is incorrect.'],
);

void main() {
  late _MockPersonRepository repository;
  late _MockGoogleUserRepository googleUsers;
  late _MockGoogleSignInGateway google;
  late _MockAuthRepository auth;
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
        authRepositoryProvider.overrideWithValue(auth),
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
        currentPassword: any(named: 'currentPassword'),
        twoFactorCode: any(named: 'twoFactorCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerStatusWith(Result<TwoFactorStatus> result) {
    when(() => auth.twoFactorStatus()).thenAnswer((_) async => result);
  }

  /// The update as it reached the repository, with the re-authentication it
  /// carried.
  ({String? currentPassword, String? twoFactorCode}) sentUpdate() {
    final call = verify(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: any(named: 'roleId'),
        currentPassword: captureAny(named: 'currentPassword'),
        twoFactorCode: captureAny(named: 'twoFactorCode'),
      ),
    )..called(1);

    return (
      currentPassword: call.captured[0] as String?,
      twoFactorCode: call.captured[1] as String?,
    );
  }

  setUp(() {
    repository = _MockPersonRepository();
    googleUsers = _MockGoogleUserRepository();
    google = _MockGoogleSignInGateway();
    when(() => google.signOut()).thenAnswer((_) async {});
    auth = _MockAuthRepository();
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

  // FR-AU-16 — changing your own address asks for your password.
  test('GivenAnEmailChange_WhenSaved_ThenThePasswordIsSent', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(const Success<Person>(_adaMoved));
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'Ada',
      email: 'new@example.com',
      currentPassword: 'secret',
    );

    // Then
    final sent = sentUpdate();
    expect(sent.currentPassword, 'secret');
    expect(sent.twoFactorCode, isNull);
  });

  // FR-AU-16 — and the second factor too, when it is on.
  test(
    'GivenTwoFactorOn_WhenTheEmailChangeIsSaved_ThenTheCodeIsSent',
    () async {
      // Given
      answerGetWith(const Success<Person>(_adaWithTwoFactor));
      answerStatusWith(
        const Success<TwoFactorStatus>(
          TwoFactorStatus(isActive: true, appEnabled: true),
        ),
      );
      answerUpdateWith(const Success<Person>(_adaMoved));
      final controller = await controllerUnderTest();
      await controller.load();

      // When
      await controller.save(
        name: 'Ada',
        email: 'new@example.com',
        currentPassword: 'secret',
        twoFactorCode: '123456',
      );

      // Then
      final sent = sentUpdate();
      expect(sent.currentPassword, 'secret');
      expect(sent.twoFactorCode, '123456');
    },
  );

  // A code typed for someone whose second factor is off is not theirs to
  // send: the API would ignore it, and it has no business travelling.
  test(
    'GivenTwoFactorOff_WhenTheEmailChangeIsSaved_ThenNoCodeIsSent',
    () async {
      // Given
      answerGetWith(const Success<Person>(_ada));
      answerUpdateWith(const Success<Person>(_adaMoved));
      final controller = await controllerUnderTest();
      await controller.load();

      // When
      await controller.save(
        name: 'Ada',
        email: 'new@example.com',
        currentPassword: 'secret',
        twoFactorCode: '123456',
      );

      // Then
      expect(sentUpdate().twoFactorCode, isNull);
    },
  );

  test('GivenANameOnlyChange_WhenSaved_ThenNoPasswordIsSent', () async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(
      const Success<TwoFactorStatus>(
        TwoFactorStatus(isActive: true, appEnabled: true),
      ),
    );
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
    await controller.save(
      name: 'Ada L',
      email: 'ada@example.com',
      currentPassword: 'secret',
      twoFactorCode: '123456',
    );

    // Then
    final sent = sentUpdate();
    expect(sent.currentPassword, isNull);
    expect(sent.twoFactorCode, isNull);
  });

  // The API compares addresses exactly, so a change of case alone is a change
  // of address: it is confirmed, and it signs the person out.
  test('GivenACaseOnlyEmailChange_WhenSaved_ThenThePasswordIsSent', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const Success<Person>(
        Person(
          id: 'person-1',
          name: 'Ada',
          email: 'Ada@example.com',
          role: Role.user,
        ),
      ),
    );
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.save(
      name: 'Ada',
      email: 'Ada@example.com',
      currentPassword: 'secret',
    );

    // Then
    expect(sentUpdate().currentPassword, 'secret');
    final session = container.read(sessionControllerProvider);
    expect((session as Unauthenticated).credentialsChanged, isTrue);
  });

  // FR-AU-28 — the change revokes the token that made it, so the session ends
  // here, and the sign-in screen says why.
  test(
    'GivenAnEmailChange_WhenSaved_ThenTheSessionEndsWithTheReason',
    () async {
      // Given
      answerGetWith(const Success<Person>(_ada));
      answerUpdateWith(const Success<Person>(_adaMoved));
      final controller = await controllerUnderTest();
      await controller.load();

      // When
      await controller.save(
        name: 'Ada',
        email: 'new@example.com',
        currentPassword: 'secret',
      );

      // Then
      final session = container.read(sessionControllerProvider);
      expect((session as Unauthenticated).credentialsChanged, isTrue);
      expect(session.sessionExpired, isFalse);
      expect(await store.read(), isNull);
    },
  );

  test('GivenANameOnlyChange_WhenSaved_ThenTheSessionStays', () async {
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
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
    expect(
      (container.read(profileControllerProvider) as ProfileLoaded).saved,
      isTrue,
    );
  });

  // AF-08h — a wrong password is the person's to correct.
  test(
    'GivenAWrongPassword_WhenSaved_ThenItIsShownAndTheSessionStays',
    () async {
      // Given
      answerGetWith(const Success<Person>(_ada));
      answerUpdateWith(const FailureResult<Person>(_wrongPassword));
      final controller = await controllerUnderTest();
      await controller.load();

      // When
      await controller.save(
        name: 'Ada',
        email: 'new@example.com',
        currentPassword: 'wrong',
      );

      // Then
      final state = container.read(profileControllerProvider) as ProfileLoaded;
      expect(state.saveFailure?.errors, <String>[
        'The current password is incorrect.',
      ]);
      expect(state.person.email, 'ada@example.com');
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  // The update answers without the second factor, and a name cannot have
  // changed it, so what was read still holds for the next edit.
  test('GivenTwoFactorOn_WhenANameIsSaved_ThenItIsStillKnownToBeOn', () async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(
      const Success<TwoFactorStatus>(
        TwoFactorStatus(isActive: true, appEnabled: true),
      ),
    );
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
    await controller.readSecondFactor();

    // When
    await controller.save(name: 'Ada L', email: 'ada@example.com');

    // Then
    final state = container.read(profileControllerProvider) as ProfileLoaded;
    expect(state.person.twoFactorEnabled, isTrue);
    expect(state.secondFactor?.appEnabled, isTrue);
  });

  // Which method is on decides what the code field suggests: no emailed code
  // is sent while signed in, so an email-only person needs a recovery code.
  test('GivenTwoFactorOn_WhenItsMethodsAreRead_ThenTheyAreKept', () async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(
      const Success<TwoFactorStatus>(
        TwoFactorStatus(isActive: true, emailEnabled: true),
      ),
    );
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.readSecondFactor();

    // Then
    final state = container.read(profileControllerProvider) as ProfileLoaded;
    expect(state.secondFactor?.methods, <TwoFactorMethod>[
      TwoFactorMethod.email,
    ]);
  });

  // The home screen loads the record too, and has no use for the methods.
  test('GivenTwoFactorOn_WhenLoaded_ThenItsMethodsAreNotAsked', () async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    final controller = await controllerUnderTest();

    // When
    await controller.load();

    // Then
    verifyNever(() => auth.twoFactorStatus());
  });

  test('GivenTwoFactorOff_WhenItsMethodsAreRead_ThenNothingIsAsked', () async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.readSecondFactor();

    // Then
    verifyNever(() => auth.twoFactorStatus());
  });

  // The methods only shape a hint, so a failed read of them leaves the
  // profile usable.
  test('GivenUnreadableMethods_WhenRead_ThenTheProfileStays', () async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(
      const FailureResult<TwoFactorStatus>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    final controller = await controllerUnderTest();
    await controller.load();

    // When
    await controller.readSecondFactor();

    // Then
    final state = container.read(profileControllerProvider) as ProfileLoaded;
    expect(state.person.twoFactorEnabled, isTrue);
    expect(state.secondFactor, isNull);
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
