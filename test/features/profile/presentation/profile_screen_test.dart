import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

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
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _compact,
    ThemeData? theme,
    int role = 3,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: _jwt(role: role),
        expiresAt: DateTime.utc(2030),
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(persons),
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
    when(
      () => auth.resendVerificationEmail(),
    ).thenAnswer((_) async => const Success<void>(null));
    await pump(tester);
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
  testWidgets('GivenAUser_WhenRendered_ThenNoNavigationIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.byType(NavigationBar), findsNothing);
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
}
