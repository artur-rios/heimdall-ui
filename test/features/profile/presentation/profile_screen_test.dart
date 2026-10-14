import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_avatar.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

class _MockGoogleSignInGateway extends Mock implements GoogleSignInGateway {}

String _jwt({int role = 3}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'email': 'ada@example.com',
        'role': role,
      }),
    ),
  );

  return 'header.$payload.signature';
}

/// A Google sign-in's token: the subject is the Google User, in its scope.
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
  name: 'Grace Hopper',
  email: 'grace@example.com',
  scopeId: 'scope-1',
);

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
);

/// The three window classes the shell lays out differently.
const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockPersonRepository persons;
  late _MockAuthRepository auth;
  late _MockGoogleUserRepository googleUsers;
  late _MockGoogleSignInGateway google;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _compact,
    ThemeData? theme,
    int role = 3,
    bool viaGoogle = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: viaGoogle ? _googleJwt() : _jwt(role: role),
        expiresAt: DateTime.utc(2030),
        viaGoogle: viaGoogle,
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(persons),
        googleUserRepositoryProvider.overrideWithValue(googleUsers),
        googleSignInGatewayProvider.overrideWithValue(google),
        authRepositoryProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void answerGetWith(Result<Person> result) {
    when(
      () =>
          persons.getById(any(), includeDeleted: any(named: 'includeDeleted')),
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
      () => persons.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: any(named: 'roleId'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    persons = _MockPersonRepository();
    auth = _MockAuthRepository();
    googleUsers = _MockGoogleUserRepository();
    google = _MockGoogleSignInGateway();
    when(() => google.signOut()).thenAnswer((_) async {});
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAProfile_WhenOpened_ThenTheRecordIsShown', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenAProfile_WhenOpened_ThenTheRoleIsShown', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.text('User'), findsOneWidget);
  });

  // AF-08d — nothing changed, so there is nothing to save.
  testWidgets('GivenNoEdit_WhenRendered_ThenSaveIsDisabled', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Then
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('GivenAnEdit_WhenTyped_ThenSaveIsEnabled', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ada'),
      'Ada Lovelace',
    );
    await tester.pumpAndSettle();

    // Then
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(button.onPressed, isNotNull);
  });

  // AF-08a — an empty name never reaches the API.
  testWidgets('GivenAnEmptyName_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(const Success<Person>(_ada));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.widgetWithText(TextFormField, 'Ada'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => persons.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: any(named: 'roleId'),
      ),
    );
  });

  testWidgets('GivenAMalformedEmail_WhenSubmitted_ThenTheFieldSaysSo', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(const Success<Person>(_ada));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ada@example.com'),
      'not-an-address',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  // AF-08b — the API's own errors, shown as returned, with the input kept.
  testWidgets('GivenARejectedSave_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
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
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ada@example.com'),
      'taken@example.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Email is already taken.'), findsOneWidget);
  });

  testWidgets('GivenARejectedSave_WhenSubmitted_ThenTheInputIsKept', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ada@example.com'),
      'taken@example.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.widgetWithText(TextFormField, 'taken@example.com'),
      findsOneWidget,
    );
  });

  // AF-08c — a changed address is unverified again, and the resend is offered.
  testWidgets('GivenAChangedEmail_WhenSaved_ThenTheResendIsOffered', (
    tester,
  ) async {
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
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ada@example.com'),
      'new@example.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.widgetWithText(TextButton, 'Send verification email'),
      findsOneWidget,
    );
  });

  testWidgets('GivenAChangedEmail_WhenResendTapped_ThenTheApiIsAsked', (
    tester,
  ) async {
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
    when(() => auth.resendVerificationEmail())
        .thenAnswer((_) async => const Success<void>(null));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ada@example.com'),
      'new@example.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(
      find.widgetWithText(TextButton, 'Send verification email'),
    );
    await tester.pumpAndSettle();

    // Then
    verify(() => auth.resendVerificationEmail()).called(1);
  });

  testWidgets('GivenAnUnchangedEmail_WhenSaved_ThenOnlySavedIsSaid', (
    tester,
  ) async {
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
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.widgetWithText(TextFormField, 'Ada'), 'Ada L');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Saved.'), findsOneWidget);
  });

  // AF-08e — the record was deleted from under the session.
  testWidgets('GivenAMissingRecord_WhenOpened_ThenTheSignOutIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Your account no longer exists'), findsOneWidget);
  });

  testWidgets('GivenATransportFailure_WhenOpened_ThenTheFailureIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.network,
          errors: <String>['Could not reach the API.'],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Could not reach the API.'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenARailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, size: _medium, role: 2);

    // Then
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('GivenAnExpandedWindow_WhenRendered_ThenAnExtendedRailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, size: _expanded, role: 2);

    // Then
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenABottomBarIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, size: _compact, role: 2);

    // Then
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  // A plain User is offered only their own profile, and one destination is not
  // navigation.
  // A User has Home and Profile, which is navigation enough to show.
  testWidgets('GivenAUser_WhenRendered_ThenHomeAndProfileAreOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheRecordIsStillShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Your details'), findsOneWidget);
  });

  // UI-33 — offered beside the person's own security settings, at every width
  // and in the dark theme.
  for (final (label, size, dark) in <(String, Size, bool)>[
    ('Compact', _compact, false),
    ('Medium', _medium, false),
    ('Expanded', _expanded, false),
    ('Dark', _medium, true),
  ]) {
    testWidgets(
      'Given${label}Profile_WhenRendered_ThenRestrictingProcessingIsOffered',
      (tester) async {
        // Given
        answerGetWith(const Success<Person>(_ada));

        // When
        await pump(tester, size: size, theme: dark ? buildDarkTheme() : null);

        // Then
        expect(find.text('Restrict processing of my account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('GivenTheRestrictionEntry_WhenTapped_ThenTheDialogOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester);
    final entry = find.text('Restrict processing of my account');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();

    // When
    await tester.tap(entry);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Restrict processing of your account?'), findsOneWidget);
  });

  // #133 — a Google User's own record, read-only: Google owns the name and the
  // address, and the API offers no way to change either.
  testWidgets('GivenAGoogleSession_WhenOpened_ThenTheirRecordIsShown', (
    tester,
  ) async {
    // Given
    answerGoogleGetWith(const Success<GoogleUser>(_grace));

    // When
    await pump(tester, viaGoogle: true);

    // Then
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('grace@example.com'), findsOneWidget);
    expect(
      find.text('Your name and email come from your Google account.'),
      findsOneWidget,
    );
    expect(find.byType(GoogleAvatar), findsOneWidget);
  });

  testWidgets('GivenAGoogleSession_WhenOpened_ThenNothingIsEditable', (
    tester,
  ) async {
    // Given
    answerGoogleGetWith(const Success<GoogleUser>(_grace));

    // When
    await pump(tester, viaGoogle: true);

    // Then
    expect(find.text('Edit'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.text('Send verification email'), findsNothing);
  });

  testWidgets('GivenAGooglePicture_WhenOpened_ThenItIsShown', (tester) async {
    // Given
    answerGoogleGetWith(
      const Success<GoogleUser>(
        GoogleUser(
          id: 'google-1',
          name: 'Grace Hopper',
          email: 'grace@example.com',
          profilePictureUrl: 'https://example.invalid/grace.png',
        ),
      ),
    );

    // When
    await pump(tester, viaGoogle: true);

    // Then
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byType(GoogleAvatar),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(avatar.foregroundImage, isA<NetworkImage>());
  });

  // AF-08e still holds for a Google User deleted from under the session.
  testWidgets(
    'GivenAMissingGoogleRecord_WhenOpened_ThenTheSignOutIsExplained',
    (tester) async {
      // Given
      answerGoogleGetWith(
        const FailureResult<GoogleUser>(
          Failure(kind: FailureKind.notFound, errors: <String>[]),
        ),
      );

      // When
      await pump(tester, viaGoogle: true);

      // Then
      expect(find.text('Your account no longer exists'), findsOneWidget);
    },
  );

  // UI-33 serves a Google User too, beside the security entry, at every width
  // and in the dark theme.
  for (final (label, size, dark) in <(String, Size, bool)>[
    ('Compact', _compact, false),
    ('Medium', _medium, false),
    ('Expanded', _expanded, false),
    ('Dark', _medium, true),
  ]) {
    testWidgets(
      'Given${label}GoogleProfile_WhenRendered_ThenItsEntriesAreOffered',
      (tester) async {
        // Given
        answerGoogleGetWith(const Success<GoogleUser>(_grace));

        // When
        await pump(
          tester,
          size: size,
          theme: dark ? buildDarkTheme() : null,
          viaGoogle: true,
        );

        // Then
        expect(find.text('Grace Hopper'), findsOneWidget);
        expect(find.text('Security'), findsOneWidget);
        expect(find.text('Restrict processing of my account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('GivenAGoogleProfile_WhenRestrictionTapped_ThenTheDialogOpens', (
    tester,
  ) async {
    // Given
    answerGoogleGetWith(const Success<GoogleUser>(_grace));
    await pump(tester, viaGoogle: true);
    final entry = find.text('Restrict processing of my account');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();

    // When
    await tester.tap(entry);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Restrict processing of your account?'), findsOneWidget);
  });
}
