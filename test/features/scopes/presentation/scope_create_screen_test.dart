import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/persons/domain/person_repository.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_create_screen.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

class _MockPersonRepository extends Mock implements PersonRepository {}

String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'email': 'admin@example.com',
        'role': 1,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _created = Scope(
  id: 'scope-9',
  name: 'Acme',
  description: 'The first tenant',
  ownerIds: <String>['person-1'],
);

/// The Scope Admins the picker offers.
const _ada = PersonSummary(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
);

const _grace = PersonSummary(
  id: 'person-2',
  name: 'Grace',
  email: 'grace@example.com',
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockScopeRepository repository;
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
        scopeRepositoryProvider.overrideWithValue(repository),
        personRepositoryProvider.overrideWithValue(persons),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/new',
          builder: (context, state) => const ScopeCreateScreen(),
        ),
        GoRoute(
          path: '/scopes/:id',
          builder: (context, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['id']}')),
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

  void answerCreateWith(Result<Scope> result) {
    when(
      () => repository.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
        ownerIds: any(named: 'ownerIds'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Opens the picker and chooses [who] from it.
  Future<void> addOwner(WidgetTester tester, String who) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, who));
    await tester.pumpAndSettle();
  }

  Future<void> fillIn(
    WidgetTester tester, {
    String name = 'Acme',
    bool withOwner = true,
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
    await tester.pumpAndSettle();

    if (withOwner) {
      await addOwner(tester, 'Ada');
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockScopeRepository();
    persons = _MockPersonRepository();
    store = InMemoryTokenStore();
    when(
      () => persons.listScopeAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        excludeOwnersOfScopeId: any(named: 'excludeOwnersOfScopeId'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Success<envelope.Page<PersonSummary>>(
        envelope.Page<PersonSummary>(
          items: <PersonSummary>[_ada, _grace],
          pageNumber: 1,
          pageSize: 50,
          totalItems: 2,
          totalPages: 1,
        ),
      ),
    );
    when(
      () => repository.list(
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Success<envelope.Page<Scope>>(
        envelope.Page<Scope>(
          items: <Scope>[],
          pageNumber: 1,
          pageSize: 20,
          totalItems: 0,
          totalPages: 1,
        ),
      ),
    );
  });

  testWidgets('GivenACompleteForm_WhenSubmitted_ThenTheScopeIsCreated', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.create(
        name: 'Acme',
        description: '',
        ownerIds: <String>['person-1'],
      ),
    ).called(1);
  });

  testWidgets('GivenACreatedScope_WhenCreated_ThenItsDetailOpens', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail scope-9'), findsOneWidget);
  });

  // AF-11a — an empty name never reaches the API.
  testWidgets('GivenNoName_WhenSubmitted_ThenNoRequestIsMade', (tester) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await fillIn(tester, name: '');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
        ownerIds: any(named: 'ownerIds'),
      ),
    );
  });

  // AF-11a — nor does a scope with nobody to own it.
  testWidgets('GivenNoOwner_WhenSubmitted_ThenNoRequestIsMade', (tester) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await fillIn(tester, withOwner: false);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
        ownerIds: any(named: 'ownerIds'),
      ),
    );
  });

  testWidgets('GivenNoOwner_WhenSubmitted_ThenTheFormSaysSo', (tester) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await fillIn(tester, withOwner: false);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('No owners added yet.'), findsOneWidget);
  });

  testWidgets('GivenAChosenScopeAdmin_WhenAdded_ThenAChipNamesThem', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);

    // When
    await addOwner(tester, 'Ada');

    // Then
    expect(find.widgetWithText(InputChip, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenAnAddedOwner_WhenRemoved_ThenTheChipGoes', (tester) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await addOwner(tester, 'Ada');

    // When
    await tester.tap(find.byTooltip('Remove owner'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(InputChip, 'Ada'), findsNothing);
  });

  // The scope does not exist yet, so the API cannot leave out the owners
  // already chosen here — the form does it.
  testWidgets('GivenAnAddedOwner_WhenPickingAgain_ThenTheyAreNotOffered', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await addOwner(tester, 'Ada');

    // When
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add owner'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(ListTile, 'Ada'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Grace'), findsOneWidget);
  });

  testWidgets('GivenTwoChosenOwners_WhenSubmitted_ThenBothAreSent', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await fillIn(tester);
    await addOwner(tester, 'Grace');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.create(
        name: 'Acme',
        description: '',
        ownerIds: <String>['person-1', 'person-2'],
      ),
    ).called(1);
  });

  // AF-11b — the API's own errors, with the form left as it was.
  testWidgets('GivenADuplicateName_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A scope with that name already exists.'],
        ),
      ),
    );
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('A scope with that name already exists.'), findsOneWidget);
  });

  testWidgets('GivenARejectedCreate_WhenSubmitted_ThenTheInputIsKept', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextFormField, 'Acme'), findsOneWidget);
  });

  // AF-11c — an owner the API will not accept.
  testWidgets('GivenARejectedOwner_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['person-1 is not a Scope Admin.'],
        ),
      ),
    );
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('person-1 is not a Scope Admin.'), findsOneWidget);
  });

  // AF-11e — nothing was created, so the same submission is offered again.
  testWidgets('GivenATransportFailure_WhenSubmitted_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create scope'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  // AF-11d — leaving a modified form asks first.
  testWidgets('GivenAModifiedForm_WhenCancelled_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
    await pump(tester);
    await fillIn(tester);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Discard this scope?'), findsOneWidget);
  });

  testWidgets('GivenAModifiedForm_WhenDiscardConfirmed_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));
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
    answerCreateWith(const Success<Scope>(_created));
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
    // Given
    answerCreateWith(const Success<Scope>(_created));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('Create a scope'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Create a scope'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheFormIsStillShown', (
    tester,
  ) async {
    // Given
    answerCreateWith(const Success<Scope>(_created));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Create a scope'), findsOneWidget);
  });
}
