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
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_detail_screen.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

/// A token naming a person of [role]: 1 System Admin, 2 Scope Admin.
String _jwt({int role = 1}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'email': 'admin@example.com',
        'role': role,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  ownerIds: <String>['person-1'],
);

const _googleOff = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  ownerIds: <String>['person-1'],
);

const _deleted = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  isDeleted: true,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockScopeRepository repository;
  late _MockGoogleUserRepository googleUsers;
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
        scopeRepositoryProvider.overrideWithValue(repository),
        googleUserRepositoryProvider.overrideWithValue(googleUsers),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId',
          builder: (context, state) =>
              ScopeDetailScreen(scopeId: state.pathParameters['scopeId']!),
        ),
        GoRoute(
          path: '/scopes/:scopeId/persons',
          builder: (context, state) => const Scaffold(body: Text('persons')),
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

  void answerGetWith(Result<Scope> result) {
    when(
      () => repository.getById(
        any(),
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

  void answerToggleWith(Result<Scope> result) {
    when(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerCountWith(Result<int> result) {
    when(() => googleUsers.countIn(any())).thenAnswer((_) async => result);
  }

  void answerDeleteWith(Result<void> result) {
    when(() => repository.delete(any())).thenAnswer((_) async => result);
  }

  void answerHardDeleteWith(Result<void> result) {
    when(() => repository.hardDelete(any())).thenAnswer((_) async => result);
  }

  /// The listing behind the detail is reloaded after a deletion; what it
  /// answers does not matter here, only that it answers.
  void answerListWith() {
    when(
      () => repository.list(
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<envelope.Page<Scope>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
  }

  void answerUpdateWith(Result<Scope> result) {
    when(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockScopeRepository();
    googleUsers = _MockGoogleUserRepository();
    store = InMemoryTokenStore();
    answerCountWith(const Success<int>(0));
  });

  testWidgets('GivenAScope_WhenOpened_ThenTheRecordIsShown', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextFormField, 'Acme'), findsOneWidget);
  });

  testWidgets('GivenAScope_WhenOpened_ThenItsContentsAreLinked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(ListTile, 'Persons'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Applications'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Permissions'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Google users'), findsOneWidget);
  });

  testWidgets('GivenALinkedSection_WhenTapped_ThenItOpens', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(ListTile, 'Persons'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('persons'), findsOneWidget);
  });

  testWidgets('GivenAnEdit_WhenSaved_ThenTheNewValuesAreSent', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerUpdateWith(
      const Success<Scope>(
        Scope(id: 'scope-1', name: 'Acme Ltd', description: 'The first tenant'),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Acme'),
      'Acme Ltd',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.update(
        id: 'scope-1',
        name: 'Acme Ltd',
        description: 'The first tenant',
      ),
    ).called(1);
  });

  // AF-12a — no such scope.
  testWidgets('GivenAMissingScope_WhenOpened_ThenNotFoundIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Scope not found'), findsOneWidget);
  });

  testWidgets('GivenAMissingScope_WhenBackTapped_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Back to scopes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  // AF-12b — the scope is not this caller's.
  testWidgets('GivenAForbiddenScope_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  // AF-12c — the API's own errors, with the record left as it was.
  testWidgets('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerUpdateWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A scope with that name already exists.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Acme'),
      'Globex',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('A scope with that name already exists.'), findsOneWidget);
  });

  testWidgets('GivenARejectedUpdate_WhenSaved_ThenTheInputIsKept', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerUpdateWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Acme'),
      'Globex',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextFormField, 'Globex'), findsOneWidget);
  });

  // AF-12d — a deleted scope is shown, marked, and read-only.
  testWidgets('GivenADeletedScope_WhenOpened_ThenItIsMarkedDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This scope is deleted'), findsOneWidget);
  });

  testWidgets('GivenADeletedScope_WhenOpened_ThenSavingIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsNothing);
  });

  // AF-12e — nothing changed, so there is nothing to save.
  testWidgets('GivenNoEdit_WhenRendered_ThenSaveIsDisabled', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

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
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Acme'),
      'Acme Ltd',
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
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.widgetWithText(TextFormField, 'Acme'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.widgetWithText(TextFormField, 'Acme'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheDetailIsStillShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.widgetWithText(TextFormField, 'Acme'), findsOneWidget);
  });

  // AF-13e — a Scope Admin never sees either control.
  testWidgets('GivenAScopeAdmin_WhenOpened_ThenDeletionIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, role: 2);

    // Then
    expect(find.widgetWithText(OutlinedButton, 'Delete scope'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Delete permanently'),
      findsNothing,
    );
  });

  testWidgets('GivenASystemAdmin_WhenOpened_ThenDeletionIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(OutlinedButton, 'Delete scope'), findsOneWidget);
  });

  testWidgets('GivenADeletedScope_WhenOpened_ThenDeletionIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(OutlinedButton, 'Delete scope'), findsNothing);
  });

  testWidgets('GivenTheDeleteControl_WhenTapped_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete scope'),
    );
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Delete this scope?'), findsOneWidget);
  });

  testWidgets('GivenAConfirmedDeletion_WhenConfirmed_ThenTheScopeIsDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete scope'),
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.delete('scope-1')).called(1);
  });

  testWidgets('GivenADeletedScope_WhenDeleted_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete scope'),
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  // AF-13a — the dialog closes and nothing is sent.
  testWidgets('GivenTheDeleteDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(const Success<void>(null));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete scope'),
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(() => repository.delete(any()));
  });

  // AF-13b — the API refused, and the scope stays open.
  testWidgets('GivenARefusedDeletion_WhenConfirmed_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The scope still holds users.'],
        ),
      ),
    );
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete scope'),
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('The scope still holds users.'), findsOneWidget);
  });

  // AF-13c — the confirm control stays disabled until the name matches.
  testWidgets('GivenTheHardDeleteDialog_WhenOpened_ThenConfirmIsDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );
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

  testWidgets('GivenAMistypedName_WhenTyped_ThenConfirmStaysDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.byType(TextField).last, 'acme');
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

  testWidgets('GivenTheTypedName_WhenItMatches_ThenTheScopeIsErased', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerHardDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Acme');
    await tester.pumpAndSettle();

    // When
    await tester.tap(
      find.widgetWithText(FilledButton, 'Delete permanently').last,
    );
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.hardDelete('scope-1')).called(1);
  });

  // AF-13d — already deleted is the outcome that was asked for.
  testWidgets('GivenAnAlreadyDeletedScope_WhenDeleted_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete scope'),
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  testWidgets('GivenAScope_WhenOpened_ThenTheGoogleControlReflectsIt', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester);

    // Then
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('GivenGoogleSignInOff_WhenTurnedOn_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_googleOff));
    answerToggleWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // Then
    verify(
      () => repository.setGoogleSignIn(id: 'scope-1', enabled: true),
    ).called(1);
  });

  // AF-15b — the accounts already in the scope are named before anything is
  // sent.
  testWidgets('GivenGoogleUsersPresent_WhenTurnedOff_ThenTheLossIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(3));
    await pump(tester);

    // When
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // Then
    expect(
      find.textContaining('3 Google accounts already in this scope'),
      findsOneWidget,
    );
  });

  testWidgets('GivenOneGoogleUser_WhenTurnedOff_ThenTheWarningIsSingular', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(1));
    await pump(tester);

    // When
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // Then
    expect(
      find.textContaining('1 Google account already in this scope'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheWarning_WhenConfirmed_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(3));
    await pump(tester);
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.setGoogleSignIn(id: 'scope-1', enabled: false),
    ).called(1);
  });

  testWidgets('GivenTheWarning_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(3));
    await pump(tester);
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  // Nothing will stop working, so nothing needs explaining.
  testWidgets('GivenNoGoogleUsers_WhenTurnedOff_ThenNoWarningIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(0));
    await pump(tester);

    // When
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // Then
    verify(
      () => repository.setGoogleSignIn(id: 'scope-1', enabled: false),
    ).called(1);
  });

  // A count that cannot be read warns anyway rather than staying quiet.
  testWidgets('GivenAnUnreadableCount_WhenTurnedOff_ThenTheWarningStillShows', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerToggleWith(const Success<Scope>(_googleOff));
    answerCountWith(
      const FailureResult<int>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // Then
    expect(find.text('Turn Google Sign-In off?'), findsOneWidget);
  });

  // AF-15a — the refusal is shown and the control stays where the API has it.
  testWidgets('GivenARefusedToggle_WhenAttempted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_googleOff));
    answerToggleWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That scope is not active.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tapAfterScrolling(tester, find.byType(SwitchListTile));

    // Then
    expect(find.text('That scope is not active.'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  // AF-12d — a deleted scope cannot be changed from here.
  testWidgets('GivenADeletedScope_WhenRendered_ThenTheControlIsDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
  });
}
