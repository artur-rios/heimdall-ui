import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/applications/domain/application.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential.dart';
import 'package:heimdall_ui/features/applications/domain/application_credential_repository.dart';
import 'package:heimdall_ui/features/applications/domain/application_repository.dart';
import 'package:heimdall_ui/features/applications/presentation/application_detail_screen.dart';
import 'package:heimdall_ui/features/applications/presentation/pending_secret.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:heimdall_ui/shared/forms/unsaved_changes.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/jwt.dart';
import '../../../support/pump_app.dart';

class _MockApplicationRepository extends Mock
    implements ApplicationRepository {}

class _MockCredentialRepository extends Mock
    implements ApplicationCredentialRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockScopeRepository extends Mock implements ScopeRepository {}

/// Google's half, faked; the sign-in screen the session redirect lands on
/// asks for it.
class _FakeGoogleSignInGateway implements GoogleSignInGateway {
  @override
  GoogleSignInAvailability get availability =>
      GoogleSignInAvailability.interactive;

  @override
  Future<void> initialize() async {}

  @override
  Stream<GoogleIdTokenObtained> get idTokens =>
      const Stream<GoogleIdTokenObtained>.empty();

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async =>
      const GoogleSignInCancelled();

  @override
  Future<void> signOut() async {}
}

class _MockPersonRepository extends Mock implements PersonRepository {}

const _ada = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.scopeAdmin,
);

// Real PublicIds: the app's router sends any other id to "not found".
const String _scopeId = '6f1d3a00-0000-0000-0000-0000000000a1';
const String _appId = '6f1d3a00-0000-0000-0000-0000000000b1';

const _grace = Person(
  id: 'person-2',
  name: 'Grace',
  email: 'grace@example.com',
  role: Role.scopeAdmin,
);

const _billing = Application(
  id: _appId,
  name: 'Billing',
  ownerId: 'person-1',
  scopeId: _scopeId,
);

const _deleted = Application(
  id: _appId,
  name: 'Billing',
  ownerId: 'person-1',
  scopeId: _scopeId,
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
  late _MockCredentialRepository credentials;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  /// The scope screens the app's router builds under the detail; what they
  /// are answered does not matter here, only that they are.
  ScopeRepository scopesUnderneath() {
    const failure = Failure(kind: FailureKind.network, errors: <String>[]);
    final scopes = _MockScopeRepository();
    when(
      () => scopes.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => const FailureResult<Scope>(failure));
    when(
      () => scopes.list(
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<envelope.Page<Scope>>(failure),
    );

    return scopes;
  }

  /// The app's router builds the listing under the detail; what it answers
  /// does not matter here, only that it answers.
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

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    int role = 1,
    bool realRouter = false,
  }) async {
    container = await pumpApp(
      tester,
      size: size,
      theme: theme,
      store: store,
      token: testToken(testJwt(sub: 'person-9', role: role)),
      overrides: <Override>[
        applicationRepositoryProvider.overrideWithValue(applications),
        applicationCredentialRepositoryProvider.overrideWithValue(credentials),
        personRepositoryProvider.overrideWithValue(persons),
        if (realRouter) ...<Override>[
          scopeRepositoryProvider.overrideWithValue(scopesUnderneath()),
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://localhost:8080'),
          ),
          authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
          scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
          googleSignInGatewayProvider.overrideWithValue(
            _FakeGoogleSignInGateway(),
          ),
        ],
      ],
      routerFor: (container) {
        if (realRouter) {
          // The app's own router, so its `onExit` and redirect are the ones
          // tested. It builds the scope and the listing under the detail too.
          answerListWith();
          router = container.read(routerProvider);
          router.go('/scopes/$_scopeId/applications/$_appId');

          return router;
        }

        return router = GoRouter(
          initialLocation: '/scopes/$_scopeId/applications/$_appId',
          // Nested and guarded as the app's own router is (#156).
          routes: <RouteBase>[
            GoRoute(
              path: '/scopes/:scopeId/applications',
              builder: (context, state) =>
                  const Scaffold(body: Text('listing')),
              routes: <RouteBase>[
                GoRoute(
                  path: ':applicationId',
                  builder: (context, state) => ApplicationDetailScreen(
                    scopeId: state.pathParameters['scopeId']!,
                    applicationId: state.pathParameters['applicationId']!,
                  ),
                  onExit: confirmLeaveWithUnsavedChanges,
                ),
              ],
            ),
          ],
        );
      },
    );
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
    ).thenAnswer(
      (_) async => Success<envelope.Page<Person>>(_people(const <Person>[])),
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
    ).thenAnswer((_) async => Success<envelope.Page<Person>>(_people(members)));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    applications = _MockApplicationRepository();
    persons = _MockPersonRepository();
    credentials = _MockCredentialRepository();
    when(() => credentials.list(any(), any())).thenAnswer(
      (_) async =>
          const Success<List<ApplicationCredential>>(<ApplicationCredential>[]),
    );
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

  testWidgets('GivenAnApplication_WhenOpened_ThenTheCredentialsCardIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester);

    // Then
    expect(find.text('Credentials'), findsOneWidget);
    expect(
      find.text('This application has no credentials yet.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenADeletedApplication_WhenOpened_ThenNoCredentialsCardIsShown',
    (tester) async {
      // Given
      answerGetWith(const Success<Application>(_deleted));

      // When
      await pump(tester);

      // Then
      expect(find.text('Credentials'), findsNothing);
      verifyNever(() => credentials.list(any(), any()));
    },
  );

  testWidgets(
    'GivenACredentialIssued_WhenTheListReloads_ThenTheApplicationPageIsNotReloaded',
    (tester) async {
      // Given
      answerGetWith(const Success<Application>(_billing));
      when(
        () =>
            credentials.issue(any(), any(), expiresAt: any(named: 'expiresAt')),
      ).thenAnswer(
        (_) async =>
            const Success(IssuedCredential(id: 'c9', secret: 'hds_once')),
      );
      await pump(tester);

      // When
      await tapAfterScrolling(tester, find.text('Issue credential'));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Issue'),
        ),
      );
      await tester.pumpAndSettle();

      // Then
      expect(find.text('hds_once'), findsOneWidget);
      verify(
        () => applications.getById(
          scopeId: any(named: 'scopeId'),
          id: any(named: 'id'),
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).called(1);
    },
  );

  Future<void> issueCredential(WidgetTester tester) async {
    when(
      () => credentials.issue(any(), any(), expiresAt: any(named: 'expiresAt')),
    ).thenAnswer(
      (_) async =>
          const Success(IssuedCredential(id: 'c9', secret: 'hds_once')),
    );
    await tapAfterScrolling(tester, find.text('Issue credential'));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Issue'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GivenAPendingSecret_WhenTheRealRouterLeaves_ThenItAsks', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    await pump(tester, realRouter: true);
    container.read(pendingSecretProvider.notifier).set();

    // When
    router.go('/scopes');
    await tester.pump();
    await tester.pump();

    // Then
    expect(find.text('Leave without the secret?'), findsOneWidget);
  });

  testWidgets(
    'GivenTheSecretShowing_WhenTheWindowCrossesTheBreakpoint_ThenLeavingStillAsks',
    (tester) async {
      // Given
      answerGetWith(const Success<Application>(_billing));
      await pump(tester, realRouter: true);
      await issueCredential(tester);
      expect(find.text('hds_once'), findsOneWidget);

      // When
      tester.view.physicalSize = const Size(500, 900);
      await tester.pumpAndSettle();
      router.go('/scopes');
      await tester.pumpAndSettle();

      // Then
      expect(container.read(pendingSecretProvider), isTrue);
      expect(find.text('Leave without the secret?'), findsOneWidget);
      expect(find.text('hds_once'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAPendingSecret_WhenTheSessionEnds_ThenItLeavesWithoutAsking',
    (tester) async {
      // Given
      answerGetWith(const Success<Application>(_billing));
      await pump(tester, realRouter: true);
      container.read(pendingSecretProvider.notifier).set();

      // When
      await container.read(sessionControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Leave without the secret?'), findsNothing);
      expect(router.state.uri.path, '/login');
      expect(container.read(pendingSecretProvider), isFalse);
    },
  );

  testWidgets('GivenTheMediumBand_WhenALongIdIsShown_ThenTheIdHasRoom', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    when(() => credentials.list(any(), any())).thenAnswer(
      (_) async => Success<List<ApplicationCredential>>(<ApplicationCredential>[
        ApplicationCredential(id: 'a' * 36, live: true),
      ]),
    );

    // When
    await pump(tester, size: const Size(700, 900));

    // Then
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.text('a' * 36)).width,
      greaterThanOrEqualTo(200),
    );
    await tester.ensureVisible(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke').hitTestable(), findsOneWidget);
  });

  testWidgets('GivenAnApplication_WhenEdited_ThenItsOwnerIsSelected', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));

    // When
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

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
        Application(id: _appId, name: 'Invoicing', ownerId: 'person-1'),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

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
        scopeId: _scopeId,
        id: _appId,
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
        Application(id: _appId, name: 'Billing', ownerId: 'person-2'),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

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
        scopeId: _scopeId,
        id: _appId,
        name: 'Billing',
        ownerId: 'person-2',
      ),
    ).called(1);
  });

  // A failed members read is cached for the session, so the selector offers
  // the one way out.
  testWidgets('GivenAFailedMembersRead_WhenRetried_ThenTheSelectorAppears', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    var reads = 0;
    when(
      () => persons.listScopeOwners(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async {
      reads++;

      return reads == 1
          ? const FailureResult<envelope.Page<Person>>(
              Failure(kind: FailureKind.network, errors: <String>[]),
            )
          : Success<envelope.Page<Person>>(_people(<Person>[_ada, _grace]));
    });
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(reads, 2);
  });

  // More owners than the listing holds, or an owner who left the scope: the
  // field must not look empty while Save would still send the old id.
  testWidgets('GivenAnOwnerOutsideTheList_WhenEdited_ThenTheOwnerIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerMembersWith(<Person>[_grace]);
    await pump(tester);

    // When
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Then
    final field = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(field.initialValue, 'person-1');
    expect(find.text('person-1'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    final current = tester.widget<DropdownMenuItem<String>>(
      find.widgetWithText(DropdownMenuItem<String>, 'person-1').last,
    );
    expect(current.enabled, isFalse);
  });

  testWidgets('GivenOwnerOutsideTheList_WhenSaved_ThenTheOwnerIsKept', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerMembersWith(<Person>[_grace]);
    answerUpdateWith(
      const Success<Application>(
        Application(id: _appId, name: 'Invoicing', ownerId: 'person-1'),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Billing'),
      'Invoicing',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => applications.update(
        scopeId: _scopeId,
        id: _appId,
        name: 'Invoicing',
        ownerId: 'person-1',
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
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

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
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete application'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    verify(() => applications.delete(scopeId: _scopeId, id: _appId)).called(1);
  });

  testWidgets('GivenADeletedApplication_WhenDeleted_ThenTheListingOpens', (
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
    verify(() => applications.hardDelete(scopeId: _scopeId, id: _appId))
        .called(1);
  });

  /// Opens the edit and changes the name, which is an unsaved edit.
  Future<void> editTheName(WidgetTester tester) async {
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Billing'),
      'Invoicing',
    );
    await tester.pumpAndSettle();
  }

  // #156 — Android's Back is a way off the screen too.
  testWidgets('GivenAnUnsavedEdit_WhenSystemBackIsPressed_ThenItAsksFirst', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    await pump(tester);
    await editTheName(tester);

    // When
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.text('listing'), findsOneWidget);
  });

  // The app's route asks about the pending secret and the edit both.
  testWidgets('GivenAnUnsavedEdit_WhenTheRealRouterLeaves_ThenItAsksFirst', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    await pump(tester, realRouter: true);
    await editTheName(tester);

    // When
    router.go('/scopes');
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Leave without the secret?'), findsNothing);
    expect(find.text('Discard your changes?'), findsOneWidget);
  });

  // The secret is asked about first, then the edit; keeping the edit keeps
  // the person on the application.
  testWidgets(
    'GivenASecretAndAnEdit_WhenTheRealRouterLeaves_ThenBothAreAsked',
    (tester) async {
      // Given
      answerGetWith(const Success<Application>(_billing));
      await pump(tester, realRouter: true);
      await editTheName(tester);
      container.read(pendingSecretProvider.notifier).set();

      // When
      router.go('/scopes');
      await tester.pumpAndSettle();
      expect(find.text('Leave without the secret?'), findsOneWidget);
      expect(find.text('Discard your changes?'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
      await tester.pumpAndSettle();

      // Then
      expect(find.byType(AlertDialog), findsNothing);
      expect(router.state.uri.path, '/scopes/$_scopeId/applications/$_appId');
      expect(find.widgetWithText(TextFormField, 'Invoicing'), findsOneWidget);
    },
  );

  // The edit went with the application, so the way back asks nothing.
  testWidgets('GivenAnUnsavedEdit_WhenItIsDeleted_ThenItLeavesAtOnce', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Application>(_billing));
    answerDeleteWith(const Success<void>(null));
    await pump(tester);
    await editTheName(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete application'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Discard your changes?'), findsNothing);
    expect(find.text('listing'), findsOneWidget);
  });
}
