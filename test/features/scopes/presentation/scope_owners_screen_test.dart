import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_owners_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_owners_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPersonRepository extends Mock implements PersonRepository {}

class _MockScopeInvitationRepository extends Mock
    implements ScopeInvitationRepository {}

/// A token naming the signed-in person, which AF-14f compares against.
String _jwt({String sub = 'person-9'}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': sub,
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
  role: Role.scopeAdmin,
);

const _grace = Person(
  id: 'person-2',
  name: 'Grace',
  email: 'grace@example.com',
  role: Role.scopeAdmin,
);

const _alan = Person(
  id: 'person-3',
  name: 'Alan',
  email: 'alan@example.com',
  role: Role.user,
);

/// A Scope Admin the picker offers, who does not already own the scope.
const _hedy = PersonSummary(
  id: 'person-7',
  name: 'Hedy',
  email: 'hedy@example.com',
);

envelope.Page<Person> _page(List<Person> items) => envelope.Page<Person>(
  items: items,
  pageNumber: 1,
  pageSize: 20,
  totalItems: items.length,
  totalPages: 1,
);

envelope.Page<PersonSummary> _candidates(List<PersonSummary> items) =>
    envelope.Page<PersonSummary>(
      items: items,
      pageNumber: 1,
      pageSize: 50,
      totalItems: items.length,
      totalPages: 1,
    );

final _hedyInvited = OwnerInvitation(
  id: 'invitation-1',
  inviteeId: 'person-7',
  inviteeName: 'Hedy',
  inviteeEmail: 'hedy@example.com',
  invitedByName: 'Ada',
  expiresAt: DateTime.utc(2026, 10, 23, 9),
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockPersonRepository repository;
  late _MockScopeInvitationRepository invitations;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    String signedInAs = 'person-9',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: _jwt(sub: signedInAs),
        expiresAt: DateTime.utc(2030),
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        personRepositoryProvider.overrideWithValue(repository),
        scopeInvitationRepositoryProvider.overrideWithValue(invitations),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/owners',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId',
          builder: (context, state) => const Scaffold(body: Text('detail')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/owners',
          builder: (context, state) =>
              ScopeOwnersScreen(scopeId: state.pathParameters['scopeId']!),
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

  void answerOwnersWith(Result<envelope.Page<Person>> result) {
    when(
      () => repository.listScopeOwners(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerUsersWith(Result<envelope.Page<Person>> result) {
    when(
      () => repository.listScopePersons(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerAdminsWith(Result<envelope.Page<PersonSummary>> result) {
    when(
      () => repository.listScopeAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        excludeOwnersOfScopeId: any(named: 'excludeOwnersOfScopeId'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerInvitationsWith(List<OwnerInvitation> items) {
    when(
      () => invitations.listForScope(
        any(),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Success<envelope.Page<OwnerInvitation>>(
        envelope.Page<OwnerInvitation>(
          items: items,
          pageNumber: 1,
          pageSize: 50,
          totalItems: items.length,
          totalPages: 1,
        ),
      ),
    );
  }

  /// Opens the picker and chooses [name] from it.
  Future<void> choose(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(TextButton, 'Add existing'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockPersonRepository();
    invitations = _MockScopeInvitationRepository();
    when(
      () => invitations.listForScope(
        any(),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Success<envelope.Page<OwnerInvitation>>(
        envelope.Page<OwnerInvitation>(
          items: <OwnerInvitation>[],
          pageNumber: 1,
          pageSize: 50,
          totalItems: 0,
          totalPages: 1,
        ),
      ),
    );
    store = InMemoryTokenStore();
    answerOwnersWith(
      Success<envelope.Page<Person>>(_page(<Person>[_ada, _grace])),
    );
    answerUsersWith(Success<envelope.Page<Person>>(_page(<Person>[_alan])));
    answerAdminsWith(
      Success<envelope.Page<PersonSummary>>(
        _candidates(<PersonSummary>[_hedy]),
      ),
    );
    when(
      () => repository.addScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer(
      (_) async => const Success<AddOwnerOutcome>(AddOwnerOutcome.added),
    );
    when(
      () => repository.removeScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));
    when(
      () => repository.promoteScopeUser(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) async => const Success<void>(null));
    when(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Success<Person>(_grace));
  });

  testWidgets('GivenAScope_WhenOpened_ThenItsOwnersAreListed', (tester) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('GivenAScope_WhenOpened_ThenItsUsersAreOfferedForPromotion', (
    tester,
  ) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Alan'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Promote'), findsOneWidget);
  });

  testWidgets('GivenAChosenScopeAdmin_WhenAdded_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await choose(tester, 'Hedy');

    // Then
    verify(
      () => repository.addScopeOwner(scopeId: 'scope-1', personId: 'person-7'),
    ).called(1);
  });

  // AF-14c — the people who already own the scope are left out of the listing
  // by the API, so the picker cannot offer one of them.
  testWidgets('GivenThePicker_WhenOpened_ThenCurrentOwnersAreExcluded', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Add existing'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.listScopeAdmins(
        name: any(named: 'name'),
        email: any(named: 'email'),
        excludeOwnersOfScopeId: 'scope-1',
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  testWidgets('GivenTheAddDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add existing'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.addScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    );
  });

  // AF-14b — the API refuses a person who is not a Scope Admin.
  testWidgets('GivenARejectedOwner_WhenAdded_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(
      () => repository.addScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<AddOwnerOutcome>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['person-7 is not a Scope Admin.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await choose(tester, 'Hedy');

    // Then
    expect(find.text('person-7 is not a Scope Admin.'), findsOneWidget);
  });

  // AF-14a — a scope with one owner is not offered the removal.
  testWidgets('GivenASingleOwner_WhenRendered_ThenRemovalIsDisabled', (
    tester,
  ) async {
    // Given
    answerOwnersWith(Success<envelope.Page<Person>>(_page(<Person>[_ada])));

    // When
    await pump(tester);

    // Then
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.person_remove_outlined),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenAnOwner_WhenRemovalConfirmed_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.byTooltip('Remove owner').first);
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () =>
          repository.removeScopeOwner(scopeId: 'scope-1', personId: 'person-1'),
    ).called(1);
  });

  testWidgets('GivenTheRemoveDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.byTooltip('Remove owner').first);
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.removeScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    );
  });

  // AF-14f — removing your own ownership is warned about as your own loss.
  testWidgets('GivenYourOwnOwnership_WhenRemoved_ThenTheLossIsExplained', (
    tester,
  ) async {
    // Given
    await pump(tester, signedInAs: 'person-1');

    // When
    await tester.tap(find.byTooltip('Remove owner').first);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Remove your own ownership?'), findsOneWidget);
  });

  testWidgets('GivenAnotherOwner_WhenRemoved_ThenTheyAreNamed', (tester) async {
    // Given
    await pump(tester, signedInAs: 'person-9');

    // When
    await tester.tap(find.byTooltip('Remove owner').first);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Remove Ada?'), findsOneWidget);
  });

  testWidgets('GivenAUser_WhenPromotionConfirmed_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Promote'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Promote'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () =>
          repository.promoteScopeUser(scopeId: 'scope-1', personId: 'person-3'),
    ).called(1);
  });

  // AF-14e — the dialog closes and nothing is sent.
  testWidgets('GivenThePromotionDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Promote'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.promoteScopeUser(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    );
  });

  testWidgets(
    'GivenTheCreateDialog_WhenRendered_ThenThePasswordIsANewPassword',
    (tester) async {
      // Given
      await pump(tester);

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
      await tester.pumpAndSettle();

      // Then
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.autofillHints, <String>[AutofillHints.newPassword]);
    },
  );

  testWidgets('GivenTheCreateDialog_WhenCompleted_ThenTheOwnerIsCreated', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Grace');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'grace@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret-pass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.createScopeOwner(
        scopeId: 'scope-1',
        name: 'Grace',
        email: 'grace@example.com',
        password: 'secret-pass',
      ),
    ).called(1);
  });

  // AF-14d — what the client can tell is wrong never reaches the API.
  testWidgets('GivenAnEmptyName_WhenCreated_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('GivenAMalformedEmail_WhenCreated_ThenTheFieldSaysSo', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Grace');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-address',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret-pass',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  // AF-14d — and what only the API can tell comes back as its own words.
  testWidgets('GivenARejectedDraft_WhenCreated_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<Person>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That email address is already taken.'],
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Grace');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'taken@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret-pass',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('That email address is already taken.'), findsOneWidget);
    // …in the dialog, which stays open with what was typed still in it
    expect(find.text('Create a co-owner'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Grace'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'taken@example.com'),
      findsOneWidget,
    );
  });

  // AF-17g — creating a co-owner with a password is rate limited. The 429 is
  // shown in the dialog with how long to wait, and the draft is kept.
  testWidgets('GivenARateLimitedDraft_WhenCreated_ThenTheDialogKeepsIt', (
    tester,
  ) async {
    // Given
    when(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<Person>(
        Failure(
          kind: FailureKind.rateLimited,
          errors: <String>['Too many requests.'],
          retryAfter: Duration(seconds: 30),
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Grace');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'grace@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret-pass',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Then
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Too many requests.')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Try again in 30 seconds.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Create a co-owner'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Grace'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'grace@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('GivenAnAcceptedDraft_WhenCreated_ThenTheDialogCloses', (
    tester,
  ) async {
    // Given
    when(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const Success<Person>(
        Person(
          id: 'person-7',
          name: 'Grace',
          email: 'grace@example.com',
          role: Role.scopeAdmin,
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Grace');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'grace@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret-pass',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Create a co-owner'), findsNothing);
  });

  // The screen can go busy behind the open dialog (a reload, another command).
  // Closing then would read as "owner created" when nothing was sent.
  testWidgets('GivenABusyScreen_WhenCreated_ThenTheDialogStaysAndSaysSo', (
    tester,
  ) async {
    // Given
    final release = Completer<Result<void>>();
    when(
      () => repository.removeScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) => release.future);
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create owner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Grace');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'grace@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret-pass',
    );
    final removing = container
        .read(scopeOwnersControllerProvider('scope-1').notifier)
        .removeOwner('person-2');
    await tester.pump();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Create a co-owner'), findsOneWidget);
    expect(find.byKey(const Key('owner-not-sent')), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Grace'), findsOneWidget);
    verifyNever(
      () => repository.createScopeOwner(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
    release.complete(const Success<void>(null));
    await removing;
  });

  // The picker can stay open while the screen goes busy behind it. Choosing
  // then sends nothing, and the admin must not be left thinking it did.
  testWidgets('GivenABusyScreen_WhenAnOwnerIsChosen_ThenNothingSentIsSaid', (
    tester,
  ) async {
    // Given
    final release = Completer<Result<void>>();
    when(
      () => repository.removeScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    ).thenAnswer((_) => release.future);
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add existing'));
    await tester.pumpAndSettle();
    final removing = container
        .read(scopeOwnersControllerProvider('scope-1').notifier)
        .removeOwner('person-2');
    await tester.pump();

    // When
    await tester.tap(find.widgetWithText(ListTile, 'Hedy'));
    await tester.pumpAndSettle();

    // Then
    expect(find.byKey(const Key('owner-add-not-sent')), findsOneWidget);
    verifyNever(
      () => repository.addScopeOwner(
        scopeId: any(named: 'scopeId'),
        personId: any(named: 'personId'),
      ),
    );
    release.complete(const Success<void>(null));
    await removing;
  });

  testWidgets('GivenAFailedListing_WhenOpened_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    answerOwnersWith(
      const FailureResult<envelope.Page<Person>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheOwnersAreListed', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheOwnersAreListed', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheOwnersAreStillListed', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets(
    'GivenAScopeAdminsAdd_WhenTheApiInvites_ThenInvitationSentAndThePendingInvitationAreShown',
    (tester) async {
      // Given — AF-14h
      when(
        () => repository.addScopeOwner(
          scopeId: any(named: 'scopeId'),
          personId: any(named: 'personId'),
        ),
      ).thenAnswer(
        (_) async => const Success<AddOwnerOutcome>(AddOwnerOutcome.invited),
      );
      await pump(tester);
      answerInvitationsWith(<OwnerInvitation>[_hedyInvited]);

      // When
      await choose(tester, 'Hedy');

      // Then
      expect(find.text('Invitation sent'), findsOneWidget);
      expect(find.text('Pending invitations'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Hedy'), findsOneWidget);
    },
  );

  // A guard: it passes before the notice exists, so it was written after GREEN.
  testWidgets(
    'GivenASystemAdminsAdd_WhenTheApiAdds_ThenNoInvitationNoticeIsShown',
    (tester) async {
      // Given — the default stub answers "added"
      await pump(tester);

      // When
      await choose(tester, 'Hedy');

      // Then
      expect(find.text('Invitation sent'), findsNothing);
    },
  );

  testWidgets(
    'GivenAPendingInvitation_WhenOpened_ThenItIsListedWithItsExpiry',
    (tester) async {
      // Given
      answerInvitationsWith(<OwnerInvitation>[_hedyInvited]);

      // When
      await pump(tester);

      // Then
      expect(find.text('Pending invitations'), findsOneWidget);
      expect(find.textContaining('hedy@example.com · Expires'), findsOneWidget);
    },
  );

  // A guard: it passes before the section exists, so it was written after GREEN.
  testWidgets('GivenNoPendingInvitations_WhenOpened_ThenTheSectionIsHidden', (
    tester,
  ) async {
    // Given — the default stub answers an empty page
    // When
    await pump(tester);

    // Then
    expect(find.text('Pending invitations'), findsNothing);
  });

  testWidgets(
    'GivenAnInvitationWithoutAnExpiry_WhenOpened_ThenOnlyTheAddressIsShown',
    (tester) async {
      // Given
      answerInvitationsWith(<OwnerInvitation>[
        const OwnerInvitation(
          id: 'invitation-2',
          inviteeId: 'person-7',
          inviteeName: 'Hedy',
          inviteeEmail: 'hedy@example.com',
        ),
      ]);

      // When
      await pump(tester);

      // Then
      expect(find.text('hedy@example.com'), findsWidgets);
      expect(find.textContaining('Expires'), findsNothing);
    },
  );

  testWidgets(
    'GivenAPendingInvitation_WhenWithdrawConfirmed_ThenTheApiIsAsked',
    (tester) async {
      // Given
      answerInvitationsWith(<OwnerInvitation>[_hedyInvited]);
      when(() => invitations.withdraw(any(), any()))
          .thenAnswer((_) async => const Success<void>(null));
      await pump(tester);
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Withdraw'));
      await tester.tap(find.widgetWithText(TextButton, 'Withdraw'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw the invitation to Hedy?'), findsOneWidget);

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();

      // Then
      verify(() => invitations.withdraw('scope-1', 'invitation-1')).called(1);
    },
  );

  testWidgets(
    'GivenAnInvitationNoLongerOpen_WhenWithdrawn_ThenTheApiMessageIsShown',
    (tester) async {
      // Given
      answerInvitationsWith(<OwnerInvitation>[_hedyInvited]);
      when(() => invitations.withdraw(any(), any())).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.notFound,
            errors: <String>[
              'The invitation was not found or is no longer open.',
            ],
          ),
        ),
      );
      await pump(tester);
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Withdraw'));
      await tester.tap(find.widgetWithText(TextButton, 'Withdraw'));
      await tester.pumpAndSettle();

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();

      // Then
      expect(
        find.text('The invitation was not found or is no longer open.'),
        findsOneWidget,
      );
    },
  );

  // A guard: nothing is sent before the button exists, so it was written after
  // GREEN.
  testWidgets('GivenTheWithdrawDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerInvitationsWith(<OwnerInvitation>[_hedyInvited]);
    await pump(tester);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Withdraw'));
    await tester.tap(find.widgetWithText(TextButton, 'Withdraw'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(() => invitations.withdraw(any(), any()));
  });

  // A Scope Admin who removed their own ownership is refused the scope from
  // then on, and a Retry would only be refused again.
  testWidgets('GivenAForbiddenScope_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerOwnersWith(
      const FailureResult<envelope.Page<Person>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
