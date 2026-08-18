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
import 'package:heimdall_ui/features/persons/presentation/person_detail_screen.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

/// A token naming the signed-in person, which AF-18e compares against.
String _jwt({String sub = 'person-9', int role = 1}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': sub,
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
  scopeId: 'scope-1',
);

const _deleted = Person(
  id: 'person-1',
  name: 'Ada',
  email: 'ada@example.com',
  role: Role.user,
  isDeleted: true,
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
    String signedInAs = 'person-9',
    int role = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: _jwt(sub: signedInAs, role: role),
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
      initialLocation: '/scopes/scope-1/persons/person-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/persons',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/persons/:personId',
          builder: (context, state) => PersonDetailScreen(
            scopeId: state.pathParameters['scopeId']!,
            personId: state.pathParameters['personId']!,
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

  void answerGetWith(Result<Person> result) {
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
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<envelope.Page<Person>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
  }

  void answerUpdateWith(Result<Person> result) {
    when(
      () => repository.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        roleId: any(named: 'roleId'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockPersonRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAPerson_WhenOpened_ThenTheRecordIsShown', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenAPerson_WhenOpened_ThenTheirFactsAreShown', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.text('User'), findsOneWidget);
    expect(find.text('scope-1'), findsOneWidget);
  });

  testWidgets('GivenAnEdit_WhenSaved_ThenTheNewValuesAreSent', (tester) async {
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
    verify(
      () => repository.update(
        id: 'person-1',
        name: 'Ada L',
        email: 'ada@example.com',
      ),
    ).called(1);
  });

  // AF-18a — no such person.
  testWidgets('GivenAMissingPerson_WhenOpened_ThenNotFoundIsShown', (
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
    expect(find.text('Person not found'), findsOneWidget);
  });

  testWidgets('GivenAMissingPerson_WhenBackTapped_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
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

  // AF-18b — the person is out of this role's reach.
  testWidgets('GivenAForbiddenPerson_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Person>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  // AF-18c — the API's own errors, with the typed input kept.
  testWidgets('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerUpdateWith(
      const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That email address is already registered.'],
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
    expect(
      find.text('That email address is already registered.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, 'taken@example.com'),
      findsOneWidget,
    );
  });

  // AF-18d — a deleted person is shown, marked, and read-only.
  testWidgets('GivenADeletedPerson_WhenOpened_ThenTheyAreMarkedDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This person is deleted'), findsOneWidget);
  });

  testWidgets('GivenADeletedPerson_WhenOpened_ThenSavingIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsNothing);
  });

  // AF-18e — your own record says so, and the role is not editable anywhere.
  testWidgets('GivenYourOwnRecord_WhenOpened_ThenItSaysSo', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, signedInAs: 'person-1');

    // Then
    expect(find.textContaining('This is your own record'), findsOneWidget);
  });

  testWidgets('GivenSomebodyElsesRecord_WhenOpened_ThenNoSelfNoticeIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, signedInAs: 'person-9');

    // Then
    expect(find.textContaining('This is your own record'), findsNothing);
  });

  testWidgets('GivenAnyRecord_WhenOpened_ThenTheRoleIsNotEditable', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, signedInAs: 'person-1');

    // Then
    expect(find.byType(DropdownButtonFormField<Role>), findsNothing);
  });

  testWidgets('GivenNoEdit_WhenRendered_ThenSaveIsDisabled', (tester) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

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

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheDetailIsStillShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
  });

  testWidgets('GivenASystemAdmin_WhenOpened_ThenBothDeletionsAreOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete person'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Delete permanently'),
      findsOneWidget,
    );
  });

  // AF-19e — a Scope Admin never sees the permanent deletion.
  testWidgets('GivenAScopeAdmin_WhenOpened_ThenOnlyTheLogicalOneIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, role: 2);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete person'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Delete permanently'),
      findsNothing,
    );
  });

  // AF-19d — the controls are disabled on your own record.
  testWidgets('GivenYourOwnRecord_WhenOpened_ThenDeletionIsDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, signedInAs: 'person-1');

    // Then
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Delete person'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenYourOwnRecord_WhenOpened_ThenTheReasonIsStated', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));

    // When
    await pump(tester, signedInAs: 'person-1');

    // Then
    expect(
      find.text('You cannot delete your own account from here.'),
      findsOneWidget,
    );
  });

  // AF-18d — a deleted person has nothing left to delete.
  testWidgets('GivenADeletedPerson_WhenOpened_ThenDeletionIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(OutlinedButton, 'Delete person'), findsNothing);
  });

  testWidgets('GivenTheDeleteControl_WhenTapped_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete person'),
    );

    // Then
    expect(find.text('Delete Ada?'), findsOneWidget);
  });

  testWidgets('GivenAConfirmedDeletion_WhenConfirmed_ThenThePersonIsDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete person'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.delete('person-1')).called(1);
  });

  testWidgets('GivenADeletedPerson_WhenDeleted_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete person'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  // AF-19a — the dialog closes and nothing is sent.
  testWidgets('GivenTheDeleteDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerDeleteWith(const Success<void>(null));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete person'),
    );

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(() => repository.delete(any()));
  });

  // AF-19b — the API refused, and the person stays open.
  testWidgets('GivenARefusedDeletion_WhenConfirmed_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['They are the last owner of a scope.'],
        ),
      ),
    );
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete person'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('They are the last owner of a scope.'), findsOneWidget);
  });

  // AF-19c — the confirm control stays disabled until the address matches.
  testWidgets('GivenTheHardDeleteDialog_WhenOpened_ThenConfirmIsDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
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

  testWidgets('GivenAMistypedEmail_WhenTyped_ThenConfirmStaysDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );

    // When
    await tester.enterText(find.byType(TextField).last, 'ADA@example.com');
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

  testWidgets('GivenTheTypedEmail_WhenItMatches_ThenThePersonIsErased', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Person>(_ada));
    answerHardDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(FilledButton, 'Delete permanently'),
    );
    await tester.enterText(find.byType(TextField).last, 'ada@example.com');
    await tester.pumpAndSettle();

    // When
    await tester.tap(
      find.widgetWithText(FilledButton, 'Delete permanently').last,
    );
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.hardDelete('person-1')).called(1);
  });
}
