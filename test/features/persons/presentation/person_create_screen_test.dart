import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/persons/presentation/person_create_screen.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

/// A token naming a person of [role]: 1 System Admin, 2 Scope Admin.
String _jwt({int role = 1}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-9',
        'email': 'admin@example.com',
        'role': role,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _created = Person(
  id: 'person-9',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  emailVerified: false,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockPersonRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    int role = 1,
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
        personRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/persons/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/persons',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/persons/new',
          builder: (context, state) =>
              PersonCreateScreen(scopeId: state.pathParameters['scopeId']!),
        ),
        GoRoute(
          path: '/scopes/:scopeId/persons/:personId',
          builder: (context, state) => Scaffold(
            body: Text('detail ${state.pathParameters['personId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  Future<void> fillIn(
    WidgetTester tester, {
    String name = 'Ada',
    String email = 'ada@example.com',
    String password = 'secret',
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      password,
    );
    await tester.pumpAndSettle();
  }

  setUpAll(() => registerFallbackValue(Role.user));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockPersonRepository();
    store = InMemoryTokenStore();
    answerUserWith(const Success<Person>(_created));
    when(
      () => repository.createAdmin(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => const Success<Person>(_created));
    when(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Success<envelope.Page<Person>>(
        envelope.Page<Person>(
          items: <Person>[],
          pageNumber: 1,
          pageSize: 20,
          totalItems: 0,
          totalPages: 1,
        ),
      ),
    );
  });

  testWidgets('GivenACompleteForm_WhenSubmitted_ThenThePersonIsCreated', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

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

  testWidgets('GivenACreatedPerson_WhenCreated_ThenTheirDetailOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail person-9'), findsOneWidget);
  });

  // AF-17a — what the client can tell is wrong never reaches the API.
  testWidgets('GivenAnEmptyName_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester, name: '');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.createUser(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('GivenAMalformedEmail_WhenSubmitted_ThenTheFieldSaysSo', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester, email: 'not-an-address');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('GivenAnEmptyPassword_WhenSubmitted_ThenTheFieldSaysSo', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester, password: '');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Enter a password.'), findsOneWidget);
  });

  // AF-17b — the address is already registered.
  testWidgets('GivenARegisteredEmail_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerUserWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That email address is already registered.'],
        ),
      ),
    );
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('That email address is already registered.'),
      findsOneWidget,
    );
  });

  // AF-17c — the password does not satisfy the API's policy.
  testWidgets('GivenARejectedPassword_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerUserWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The password is too short.'],
        ),
      ),
    );
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('The password is too short.'), findsOneWidget);
  });

  testWidgets('GivenARejectedCreate_WhenSubmitted_ThenTheInputIsKept', (
    tester,
  ) async {
    // Given
    answerUserWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
  });

  // AF-17d — a Scope Admin is not offered a role they cannot create.
  testWidgets('GivenAScopeAdmin_WhenRendered_ThenOnlyUserIsOffered', (
    tester,
  ) async {
    // Given
    await pump(tester, role: 2);

    // When
    await tester.tap(find.byType(DropdownButtonFormField<Role>));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('System Admin'), findsNothing);
    expect(find.text('Scope Admin'), findsNothing);
  });

  testWidgets('GivenASystemAdmin_WhenRendered_ThenEveryRoleIsOffered', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.byType(DropdownButtonFormField<Role>));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('System Admin'), findsOneWidget);
  });

  testWidgets('GivenAnAdminRole_WhenChosen_ThenTheUnscopedEndpointIsUsed', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester, name: 'Grace', email: 'grace@example.com');
    await tester.tap(find.byType(DropdownButtonFormField<Role>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scope Admin').last);
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create person'));
    await tester.pumpAndSettle();

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

  // AF-17e — leaving a modified form asks first.
  testWidgets('GivenAModifiedForm_WhenCancelled_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Discard this person?'), findsOneWidget);
  });

  testWidgets('GivenAModifiedForm_WhenDiscardConfirmed_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await fillIn(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  testWidgets('GivenAnUntouchedForm_WhenCancelled_ThenTheListingOpensAtOnce', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('Create a person'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Create a person'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheFormIsStillShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Create a person'), findsOneWidget);
  });
}
