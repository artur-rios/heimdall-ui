import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_create_screen.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockApplicationRepository extends Mock
    implements ApplicationRepository {}

class _MockPersonRepository extends Mock implements PersonRepository {}

String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-9',
        'email': 'admin@example.com',
        'role': 1,
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

const _grace = Person(
  id: 'person-2',
  name: 'Grace',
  email: 'grace@example.com',
  role: Role.scopeAdmin,
);

const _created = Application(id: 'app-9', name: 'Billing', ownerId: 'person-1');

envelope.Page<Person> _people(List<Person> items) => envelope.Page<Person>(
  items: items,
  pageNumber: 1,
  pageSize: 100,
  totalItems: items.length,
  totalPages: 1,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockApplicationRepository applications;
  late _MockPersonRepository persons;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(AuthToken(value: _jwt(), expiresAt: DateTime.utc(2030)));

    container = ProviderContainer(
      overrides: <Override>[
        applicationRepositoryProvider.overrideWithValue(applications),
        personRepositoryProvider.overrideWithValue(persons),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/applications/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/applications',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/applications/new',
          builder: (context, state) => ApplicationCreateScreen(
            scopeId: state.pathParameters['scopeId']!,
          ),
        ),
        GoRoute(
          path: '/scopes/:scopeId/applications/:applicationId',
          builder: (context, state) => Scaffold(
            body: Text('detail ${state.pathParameters['applicationId']}'),
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

  void answerCreateWith(Result<Application> result) {
    when(
      () => applications.create(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerMembersWith({
    Result<envelope.Page<Person>>? users,
    Result<envelope.Page<Person>>? owners,
  }) {
    when(
      () => persons.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async =>
          users ?? Success<envelope.Page<Person>>(_people(<Person>[_ada])),
    );
    when(
      () => persons.listScopeOwners(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async =>
          owners ?? Success<envelope.Page<Person>>(_people(<Person>[_grace])),
    );
  }

  Future<void> chooseOwner(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    applications = _MockApplicationRepository();
    persons = _MockPersonRepository();
    store = InMemoryTokenStore();
    answerCreateWith(const Success<Application>(_created));
    answerMembersWith();
    when(
      () => applications.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<envelope.Page<Application>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
  });

  // AF-21c — the selector lists the scope's own people, users and owners both.
  testWidgets('GivenAScope_WhenOpened_ThenItsPeopleAreOffered', (tester) async {
    // Given / When
    await pump(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // Then
    expect(find.textContaining('Ada'), findsWidgets);
    expect(find.textContaining('Grace'), findsWidgets);
  });

  testWidgets('GivenACompleteForm_WhenSubmitted_ThenTheApplicationIsCreated', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();
    await chooseOwner(tester, 'Ada (ada@example.com)');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create application'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => applications.create(
        scopeId: 'scope-1',
        name: 'Billing',
        ownerId: 'person-1',
      ),
    ).called(1);
  });

  testWidgets('GivenACreatedApplication_WhenCreated_ThenItsDetailOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();
    await chooseOwner(tester, 'Ada (ada@example.com)');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create application'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail app-9'), findsOneWidget);
  });

  // AF-21a — an empty name never reaches the API.
  testWidgets('GivenNoName_WhenSubmitted_ThenNoRequestIsMade', (tester) async {
    // Given
    await pump(tester);
    await chooseOwner(tester, 'Ada (ada@example.com)');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create application'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => applications.create(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    );
  });

  // AF-21a — nor does an application with no owner.
  testWidgets('GivenNoOwner_WhenSubmitted_ThenNoRequestIsMade', (tester) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create application'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => applications.create(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    );
  });

  testWidgets('GivenNoOwner_WhenRendered_ThenTheFormSaysSo', (tester) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('No owner selected yet.'), findsOneWidget);
  });

  // AF-21b — a duplicate name, in the API's own words.
  testWidgets('GivenADuplicateName_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<Application>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['An application with that name already exists.'],
        ),
      ),
    );
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();
    await chooseOwner(tester, 'Ada (ada@example.com)');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create application'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('An application with that name already exists.'),
      findsOneWidget,
    );
  });

  // AF-21c — the API refuses an owner who is not of the scope.
  testWidgets('GivenARejectedOwner_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<Application>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That person is not of this scope.'],
        ),
      ),
    );
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();
    await chooseOwner(tester, 'Ada (ada@example.com)');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create application'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('That person is not of this scope.'), findsOneWidget);
  });

  testWidgets('GivenARejectedCreate_WhenSubmitted_ThenTheInputIsKept', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<Application>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();
    await chooseOwner(tester, 'Ada (ada@example.com)');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create application'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextFormField, 'Billing'), findsOneWidget);
  });

  testWidgets('GivenAScopeWithNobodyInIt_WhenOpened_ThenItSaysSo', (
    tester,
  ) async {
    // Given
    answerMembersWith(
      users: Success<envelope.Page<Person>>(_people(const <Person>[])),
      owners: Success<envelope.Page<Person>>(_people(const <Person>[])),
    );

    // When
    await pump(tester);

    // Then
    expect(
      find.textContaining('nobody who could own an application'),
      findsOneWidget,
    );
  });

  // Either listing failing must not hide the other.
  testWidgets(
    'GivenAFailedUserListing_WhenOpened_ThenTheOwnersAreStillOffered',
    (tester) async {
      // Given
      answerMembersWith(
        users: const FailureResult<envelope.Page<Person>>(
          Failure(kind: FailureKind.forbidden, errors: <String>[]),
        ),
      );

      // When
      await pump(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Then
      expect(find.textContaining('Grace'), findsWidgets);
    },
  );

  // AF-21d — leaving a modified form asks first.
  testWidgets('GivenAModifiedForm_WhenCancelled_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Discard this application?'), findsOneWidget);
  });

  testWidgets('GivenAModifiedForm_WhenDiscardConfirmed_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Billing',
    );
    await tester.pumpAndSettle();
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
    expect(find.text('Create an application'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Create an application'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheFormIsStillShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Create an application'), findsOneWidget);
  });
}
