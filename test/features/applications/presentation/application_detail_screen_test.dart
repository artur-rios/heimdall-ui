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
import 'package:heimdall_ui/features/applications/presentation/application_detail_screen.dart';
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

const _billing = Application(
  id: 'app-1',
  name: 'Billing',
  ownerId: 'person-1',
  scopeId: 'scope-1',
);

const _deleted = Application(
  id: 'app-1',
  name: 'Billing',
  ownerId: 'person-1',
  scopeId: 'scope-1',
  isDeleted: true,
);

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
        applicationRepositoryProvider.overrideWithValue(applications),
        personRepositoryProvider.overrideWithValue(persons),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/applications/app-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/applications',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/applications/:applicationId',
          builder: (context, state) => ApplicationDetailScreen(
            scopeId: state.pathParameters['scopeId']!,
            applicationId: state.pathParameters['applicationId']!,
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

  void answerGetWith(Result<Application> result) {
    when(
      () => applications.getById(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// The deletion controls sit at the bottom of a scrolling detail, so they
  /// are not on screen until the view is brought to them.
  Future<void> tapAfterScrolling(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void answerDeleteWith(Result<void> result) {
    when(
      () => applications.delete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerHardDeleteWith(Result<void> result) {
    when(
      () => applications.hardDelete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// The listing behind the detail is reloaded after a deletion; what it
  /// answers does not matter here, only that it answers.
  void answerListWith() {
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
  }

  void answerUpdateWith(Result<Application> result) {
    when(
      () => applications.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerMembersWith(List<Person> members) {
    when(
      () => persons.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success<envelope.Page<Person>>(_people(members)));
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
      (_) async => Success<envelope.Page<Person>>(_people(const <Person>[])),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    applications = _MockApplicationRepository();
    persons = _MockPersonRepository();
    store = InMemoryTokenStore();
    answerMembersWith(<Person>[_ada, _grace]);
  });

  testWidgets('GivenAnApplication_WhenOpened_ThenTheRecordIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextFormField, 'Billing'), findsOneWidget);
  });

  testWidgets('GivenAnApplication_WhenOpened_ThenItsOwnerIsSelected', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester);

    // Then
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'person-1',
    );
  });

  testWidgets('GivenAnEdit_WhenSaved_ThenTheNewValuesAreSent', (tester) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerUpdateWith(
      const Success<Application>(
        Application(id: 'app-1', name: 'Invoicing', ownerId: 'person-1'),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Billing'),
      'Invoicing',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => applications.update(
        scopeId: 'scope-1',
        id: 'app-1',
        name: 'Invoicing',
        ownerId: 'person-1',
      ),
    ).called(1);
  });

  testWidgets('GivenAnOwnerChange_WhenSaved_ThenTheNewOwnerIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerUpdateWith(
      const Success<Application>(
        Application(id: 'app-1', name: 'Billing', ownerId: 'person-2'),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grace (grace@example.com)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => applications.update(
        scopeId: 'scope-1',
        id: 'app-1',
        name: 'Billing',
        ownerId: 'person-2',
      ),
    ).called(1);
  });

  // AF-22a — no such application.
  testWidgets('GivenAMissingApplication_WhenOpened_ThenNotFoundIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Application>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Application not found'), findsOneWidget);
  });

  testWidgets('GivenAMissingApplication_WhenBackTapped_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Application>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Back to the listing'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  // AF-22b — out of this role's reach.
  testWidgets('GivenAForbiddenApplication_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Application>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  // AF-22c — the API's own errors, with the typed input kept.
  testWidgets('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerUpdateWith(
      const FailureResult<Application>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['An application with that name already exists.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Billing'),
      'Invoicing',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('An application with that name already exists.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Invoicing'), findsOneWidget);
  });

  // AF-22d — a deleted application is shown, marked, and read-only.
  testWidgets('GivenADeletedApplication_WhenOpened_ThenItIsMarkedDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This application is deleted'), findsOneWidget);
  });

  testWidgets('GivenADeletedApplication_WhenOpened_ThenSavingIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  // AF-22e — nothing changed, so there is nothing to save.
  testWidgets('GivenNoEdit_WhenRendered_ThenSaveIsDisabled', (tester) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester);

    // Then
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save changes'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenAnEdit_WhenTyped_ThenSaveIsEnabled', (tester) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Billing'),
      'Invoicing',
    );
    await tester.pumpAndSettle();

    // Then
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save changes'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.widgetWithText(TextFormField, 'Billing'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.widgetWithText(TextFormField, 'Billing'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheDetailIsStillShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.widgetWithText(TextFormField, 'Billing'), findsOneWidget);
  });

  testWidgets('GivenASystemAdmin_WhenOpened_ThenBothDeletionsAreOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete application'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Delete permanently'),
      findsOneWidget,
    );
  });

  // AF-23d — a Scope Admin never sees the permanent deletion.
  testWidgets('GivenAScopeAdmin_WhenOpened_ThenOnlyTheLogicalOneIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester, role: 2);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete application'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Delete permanently'),
      findsNothing,
    );
  });

  // AF-22d — a deleted application has nothing left to delete.
  testWidgets('GivenADeletedApplication_WhenOpened_ThenDeletionIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete application'),
      findsNothing,
    );
  });

  testWidgets('GivenTheDeleteControl_WhenTapped_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete application'),
    );

    // Then
    expect(find.text('Delete Billing?'), findsOneWidget);
  });

  testWidgets('GivenAConfirmedDeletion_WhenConfirmed_ThenItIsDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete application'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => applications.delete(scopeId: 'scope-1', id: 'app-1'),
    ).called(1);
  });

  testWidgets('GivenADeletedApplication_WhenDeleted_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete application'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  // AF-23a — the dialog closes and nothing is sent.
  testWidgets('GivenTheDeleteDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerDeleteWith(const Success<void>(null));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete application'),
    );

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => applications.delete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    );
  });

  // AF-23b — the API refused, and the application stays open.
  testWidgets('GivenARefusedDeletion_WhenConfirmed_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That application is still in use.'],
        ),
      ),
    );
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete application'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('That application is still in use.'), findsOneWidget);
  });

  // AF-23c — the confirm control stays disabled until the name matches.
  testWidgets('GivenTheHardDeleteDialog_WhenOpened_ThenConfirmIsDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );

    // Then
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Delete permanently').last,
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenAMistypedName_WhenTyped_ThenConfirmStaysDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );

    // When
    await tester.enterText(find.byType(TextField).last, 'billing');
    await tester.pumpAndSettle();

    // Then
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Delete permanently').last,
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenTheTypedName_WhenItMatches_ThenTheApplicationIsErased', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerHardDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );
    await tester.enterText(find.byType(TextField).last, 'Billing');
    await tester.pumpAndSettle();

    // When
    await tester.tap(
      find.widgetWithText(FilledButton, 'Delete permanently').last,
    );
    await tester.pumpAndSettle();

    // Then
    verify(
      () => applications.hardDelete(scopeId: 'scope-1', id: 'app-1'),
    ).called(1);
  });
}
