import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/domain/two_factor.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_avatar.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_screen.dart';
import 'package:heimdall_ui/shared/forms/unsaved_changes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/idle_expiry_timer.dart';

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
    bool routed = false,
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
        sessionExpiryTimerProvider.overrideWithValue(idleExpiryTimer),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    // [routed] puts the screen under a router, for a test that follows a
    // link off it.
    final router = routed
        ? GoRouter(
            initialLocation: '/profile',
            routes: <RouteBase>[
              // Nested and guarded as the app's own routes are (#156).
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                onExit: confirmLeaveWithUnsavedChanges,
                routes: <RouteBase>[
                  GoRoute(
                    path: 'security',
                    builder: (context, state) =>
                        const Scaffold(body: Text('security')),
                  ),
                ],
              ),
            ],
          )
        : null;

    if (router != null) {
      addTearDown(router.dispose);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: router == null
            ? MaterialApp(
                theme: theme ?? buildLightTheme(),
                home: const ProfileScreen(),
              )
            : MaterialApp.router(
                theme: theme ?? buildLightTheme(),
                routerConfig: router,
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
        currentPassword: any(named: 'currentPassword'),
        twoFactorCode: any(named: 'twoFactorCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerStatusWith(TwoFactorStatus status) {
    when(() => auth.twoFactorStatus())
        .thenAnswer((_) async => Success<TwoFactorStatus>(status));
  }

  /// Opens the edit and types [email] over the address.
  Future<void> changeEmailTo(WidgetTester tester, String email) async {
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ada@example.com'),
      email,
    );
    await tester.pumpAndSettle();
  }

  Finder passwordField() =>
      find.widgetWithText(TextFormField, 'Current password');

  Finder codeField() => find.widgetWithText(TextFormField, 'Two-factor code');

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
    await tester.enterText(passwordField(), 'secret');
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
    await tester.enterText(passwordField(), 'secret');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.widgetWithText(TextFormField, 'taken@example.com'),
      findsOneWidget,
    );
  });

  // FR-AU-16 — a new address asks for the current password.
  testWidgets('GivenAnEmailChange_WhenTyped_ThenThePasswordIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester);

    // When
    await changeEmailTo(tester, 'new@example.com');

    // Then
    expect(passwordField(), findsOneWidget);
    // The second factor is off, so there is no code to ask for.
    expect(codeField(), findsNothing);
  });

  // The API compares addresses exactly, so a change of case alone is a change
  // of address, and asks for the password like any other.
  testWidgets('GivenACaseOnlyEmailChange_WhenTyped_ThenThePasswordIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester);

    // When
    await changeEmailTo(tester, 'Ada@example.com');

    // Then
    expect(passwordField(), findsOneWidget);
  });

  testWidgets('GivenANameChange_WhenTyped_ThenNoPasswordIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(const TwoFactorStatus(isActive: true, appEnabled: true));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.widgetWithText(TextFormField, 'Ada'), 'Ada L');
    await tester.pumpAndSettle();

    // Then
    expect(passwordField(), findsNothing);
    expect(codeField(), findsNothing);
  });

  // FR-AU-16 — and the second factor too, when it is on. Both an
  // authenticator code and a recovery code are taken.
  testWidgets('GivenTwoFactorOn_WhenTheEmailIsChanged_ThenACodeIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(const TwoFactorStatus(isActive: true, appEnabled: true));
    await pump(tester);

    // When
    await changeEmailTo(tester, 'new@example.com');

    // Then
    expect(passwordField(), findsOneWidget);
    expect(codeField(), findsOneWidget);
    expect(
      find.text('A code from your authenticator app, or a recovery code.'),
      findsOneWidget,
    );
  });

  // A keyboard that corrects or completes words would change a code, and a
  // recovery code is sixteen characters now, sent as typed.
  testWidgets('GivenTheCodeField_WhenShown_ThenNothingRewritesIt', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(const TwoFactorStatus(isActive: true, appEnabled: true));
    await pump(tester);

    // When
    await changeEmailTo(tester, 'new@example.com');

    // Then
    final field = tester.widget<EditableText>(
      find.descendant(of: codeField(), matching: find.byType(EditableText)),
    );
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.textCapitalization, TextCapitalization.characters);
  });

  // No emailed code is sent while signed in, so a person whose only second
  // factor is email is pointed at their recovery codes.
  testWidgets(
    'GivenEmailOnlyTwoFactor_WhenTheEmailIsChanged_ThenARecoveryCodeIsSuggested',
    (tester) async {
      // Given
      answerGetWith(const Success<Person>(_adaWithTwoFactor));
      answerStatusWith(
        const TwoFactorStatus(isActive: true, emailEnabled: true),
      );
      await pump(tester);

      // When
      await changeEmailTo(tester, 'new@example.com');

      // Then
      expect(codeField(), findsOneWidget);
      expect(find.text('Use one of your recovery codes.'), findsOneWidget);
    },
  );

  // Until the method is known the field suggests nothing, so a person whose
  // only method is email is never shown the authenticator wording first.
  testWidgets(
    'GivenTheMethodBeingRead_WhenTheEmailIsChanged_ThenNoHintIsShownYet',
    (tester) async {
      // Given
      final status = Completer<Result<TwoFactorStatus>>();
      answerGetWith(const Success<Person>(_adaWithTwoFactor));
      when(() => auth.twoFactorStatus()).thenAnswer((_) => status.future);
      await pump(tester);

      // When
      await changeEmailTo(tester, 'new@example.com');

      // Then
      expect(codeField(), findsOneWidget);
      expect(
        find.text('A code from your authenticator app, or a recovery code.'),
        findsNothing,
      );
      expect(find.text('Use one of your recovery codes.'), findsNothing);

      // And once it is known
      status.complete(
        const Success<TwoFactorStatus>(
          TwoFactorStatus(isActive: true, emailEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Use one of your recovery codes.'), findsOneWidget);
    },
  );

  // When the methods could not be read, the hint covers both ways in.
  testWidgets(
    'GivenUnreadableMethods_WhenTheEmailIsChanged_ThenTheCombinedHintIsShown',
    (tester) async {
      // Given
      answerGetWith(const Success<Person>(_adaWithTwoFactor));
      when(() => auth.twoFactorStatus()).thenAnswer(
        (_) async => const FailureResult<TwoFactorStatus>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      await pump(tester);

      // When
      await changeEmailTo(tester, 'new@example.com');

      // Then
      expect(
        find.text('A code from your authenticator app, or a recovery code.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenAnEmailChangeWithoutAPassword_WhenSubmitted_ThenNoRequestIsMade',
    (tester) async {
      // Given
      answerGetWith(const Success<Person>(_ada));
      answerUpdateWith(const Success<Person>(_adaMoved));
      await pump(tester);
      await changeEmailTo(tester, 'new@example.com');

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Enter your current password.'), findsOneWidget);
      verifyNever(
        () => persons.update(
          id: any(named: 'id'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          roleId: any(named: 'roleId'),
          currentPassword: any(named: 'currentPassword'),
          twoFactorCode: any(named: 'twoFactorCode'),
        ),
      );
    },
  );

  testWidgets('GivenAPasswordAndACode_WhenTheEmailIsSaved_ThenBothAreSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(const TwoFactorStatus(isActive: true, appEnabled: true));
    answerUpdateWith(const Success<Person>(_adaMoved));
    await pump(tester);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.enterText(codeField(), '123456');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    // Signed out, the shell shows its placeholder until the application's
    // guard redirects, which this screen alone does not have: it never
    // settles.
    await tester.pump();
    await tester.pump();

    // Then
    verify(
      () => persons.update(
        id: 'person-1',
        name: 'Ada',
        email: 'new@example.com',
        roleId: any(named: 'roleId'),
        currentPassword: 'secret',
        twoFactorCode: '123456',
      ),
    ).called(1);
  });

  testWidgets('GivenANewRecoveryCode_WhenTheEmailIsSaved_ThenItIsSentWhole', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(const TwoFactorStatus(isActive: true, emailEnabled: true));
    answerUpdateWith(const Success<Person>(_adaMoved));
    await pump(tester);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.enterText(codeField(), ' abcd-efgh jkmn-pqrs ');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pump();
    await tester.pump();

    // Then
    verify(
      () => persons.update(
        id: 'person-1',
        name: 'Ada',
        email: 'new@example.com',
        roleId: any(named: 'roleId'),
        currentPassword: 'secret',
        twoFactorCode: 'abcd-efgh jkmn-pqrs',
      ),
    ).called(1);
  });

  testWidgets('GivenANameChange_WhenSaved_ThenNoPasswordIsSent', (
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
    await tester.enterText(find.widgetWithText(TextFormField, 'Ada'), 'Ada L');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => persons.update(
        id: 'person-1',
        name: 'Ada L',
        email: 'ada@example.com',
        roleId: any(named: 'roleId'),
        currentPassword: null,
        twoFactorCode: null,
      ),
    ).called(1);
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // AF-08h — a wrong password is shown where it was typed, and the person
  // stays signed in to correct it.
  testWidgets('GivenAWrongPassword_WhenSaved_ThenItIsShownInline', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The current password is incorrect.'],
        ),
      ),
    );
    await pump(tester);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'wrong');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('The current password is incorrect.'), findsOneWidget);
    expect(passwordField(), findsOneWidget);
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // AF-08i — the API will not change the address while the email sign-in
  // method is on. The refusal is shown on the form with the way out: the
  // two-factor settings, where the method is turned off.
  testWidgets(
    'GivenTheEmailMethodOn_WhenTheEmailIsSaved_ThenSecurityIsOffered',
    (tester) async {
      // Given
      answerGetWith(const Success<Person>(_adaWithTwoFactor));
      answerStatusWith(
        const TwoFactorStatus(isActive: true, emailEnabled: true),
      );
      answerUpdateWith(const FailureResult<Person>(_emailMethodOn));
      await pump(tester, routed: true);
      await changeEmailTo(tester, 'new@example.com');
      await tester.enterText(passwordField(), 'secret');
      await tester.enterText(codeField(), 'ABCD-EFGH-JKMN-PQRS');
      await tester.pumpAndSettle();

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      // Then
      expect(find.text(_emailMethodOn.errors.single), findsOneWidget);
      expect(
        find.text(
          'Turn the email method off in your security settings, change your '
          'address, then set the method up again at the new one.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'new@example.com'),
        findsOneWidget,
      );
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  testWidgets('GivenTheEmailMethodRefusal_WhenSecurityIsChosen_ThenItOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(const TwoFactorStatus(isActive: true, emailEnabled: true));
    answerUpdateWith(const FailureResult<Person>(_emailMethodOn));
    await pump(tester, routed: true);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.enterText(codeField(), 'ABCD-EFGH-JKMN-PQRS');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Open security settings'));
    await tester.pumpAndSettle();
    // The typed address is an unsaved edit, so leaving asks first.
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('security'), findsOneWidget);
  });

  // AF-08j — the change's notice counts against the account-email budget.
  testWidgets('GivenAMailCooldown_WhenTheEmailIsSaved_ThenTheWaitIsShown', (
    tester,
  ) async {
    // Given
    const cooldown =
        'An email of this kind was sent to you recently. Try again in a few '
        'minutes.';
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.rateLimited,
          errors: <String>[cooldown],
          retryAfter: Duration(seconds: 240),
        ),
      ),
    );
    await pump(tester);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text(cooldown), findsOneWidget);
    expect(find.text('Try again in 4 minutes.'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'new@example.com'),
      findsOneWidget,
    );
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  testWidgets('GivenTheEmailMethodRefusal_WhenKeptEditing_ThenTheEditStays', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_adaWithTwoFactor));
    answerStatusWith(const TwoFactorStatus(isActive: true, emailEnabled: true));
    answerUpdateWith(const FailureResult<Person>(_emailMethodOn));
    await pump(tester, routed: true);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.enterText(codeField(), 'ABCD-EFGH-JKMN-PQRS');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Open security settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('security'), findsNothing);
    expect(find.text(_emailMethodOn.errors.single), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Open security settings'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, 'new@example.com'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(passwordField()).controller?.text,
      'secret',
    );
    expect(
      tester.widget<TextFormField>(codeField()).controller?.text,
      'ABCD-EFGH-JKMN-PQRS',
    );
  });

  testWidgets('GivenAnotherConflict_WhenTheEmailIsSaved_ThenNoHintIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.conflict,
          errors: <String>['That email address is already registered.'],
        ),
      ),
    );
    await pump(tester, routed: true);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('That email address is already registered.'),
      findsOneWidget,
    );
    expect(find.text('Open security settings'), findsNothing);
  });

  // FR-AU-28 — the change revokes the token that made it, so the person is
  // signed out, with the reason kept for the sign-in screen.
  testWidgets('GivenAnEmailChange_WhenSaved_ThenTheSessionEnds', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(const Success<Person>(_adaMoved));
    await pump(tester);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    // Signed out, the shell shows its placeholder until the application's
    // guard redirects, which this screen alone does not have: it never
    // settles.
    await tester.pump();
    await tester.pump();

    // Then
    final session = container.read(sessionControllerProvider);
    expect((session as Unauthenticated).credentialsChanged, isTrue);
  });

  // A password typed for an edit that was dropped does not wait in the form
  // for the next one.
  testWidgets('GivenATypedPassword_WhenTheEditIsCancelled_ThenItIsCleared', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester);
    await changeEmailTo(tester, 'new@example.com');
    await tester.enterText(passwordField(), 'secret');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    await changeEmailTo(tester, 'other@example.com');

    // Then
    expect(tester.widget<TextFormField>(passwordField()).controller?.text, '');
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
  // #156 — Android's Back would leave the app from here, and the edit with it,
  // so it asks first; keeping the edit keeps the app open.
  testWidgets('GivenAnUnsavedEdit_WhenSystemBackIsPressed_ThenItAsksFirst', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester, routed: true);
    await changeEmailTo(tester, 'new@example.com');

    // When
    final handled = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(await handled, isTrue);
    expect(
      find.widgetWithText(TextFormField, 'new@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('GivenAnUnsavedEdit_WhenSystemBackIsDiscarded_ThenTheAppExits', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester, routed: true);
    await changeEmailTo(tester, 'new@example.com');
    final handled = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    // Then
    expect(await handled, isFalse);
  });

  // #156 — Security opens over the profile, and the second factor may have
  // changed there, so the profile is read again on the way back.
  testWidgets('GivenSecurityOpened_WhenSystemBackIsPressed_ThenItIsReadAgain', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester, routed: true);
    await tester.tap(find.widgetWithText(ListTile, 'Security'));
    await tester.pumpAndSettle();
    expect(find.text('security'), findsOneWidget);

    // When
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Then
    expect(handled, isTrue);
    expect(find.text('security'), findsNothing);
    verify(
      () =>
          persons.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).called(2);
  });

  // AF-08i — once let go, the edit is gone, not waiting under Security.
  testWidgets(
    'GivenTheEmailMethodRefusal_WhenDiscardedForSecurity_ThenItEnds',
    (tester) async {
      // Given
      answerGetWith(const Success<Person>(_adaWithTwoFactor));
      answerStatusWith(
        const TwoFactorStatus(isActive: true, emailEnabled: true),
      );
      answerUpdateWith(const FailureResult<Person>(_emailMethodOn));
      await pump(tester, routed: true);
      await changeEmailTo(tester, 'new@example.com');
      await tester.enterText(passwordField(), 'secret');
      await tester.enterText(codeField(), 'ABCD-EFGH-JKMN-PQRS');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'Open security settings'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      // When
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Discard your changes?'), findsNothing);
      expect(
        find.widgetWithText(TextFormField, 'new@example.com'),
        findsNothing,
      );
      expect(find.text(_emailMethodOn.errors.single), findsNothing);
    },
  );
}

/// The API's refusal of an own email change while the email sign-in method is
/// on (enabled or pending).
const Failure _emailMethodOn = Failure(
  kind: FailureKind.conflict,
  errors: <String>[
    'Turn off the email sign-in method before changing your email address.',
  ],
);
