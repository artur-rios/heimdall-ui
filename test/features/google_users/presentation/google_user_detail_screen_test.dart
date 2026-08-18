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
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_user_detail_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

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

const _ada = GoogleUser(
  id: 'google-1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  googleId: '1234567890',
  scopeId: 'scope-1',
);

const _deleted = GoogleUser(
  id: 'google-1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  scopeId: 'scope-1',
  isDeleted: true,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockGoogleUserRepository repository;
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
        googleUserRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/google-users/google-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/google-users',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/google-users/:googleUserId',
          builder: (context, state) => GoogleUserDetailScreen(
            scopeId: state.pathParameters['scopeId']!,
            googleUserId: state.pathParameters['googleUserId']!,
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

  void answerGetWith(Result<GoogleUser> result) {
    when(
      () => repository.getById(
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
      () => repository.delete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerHardDeleteWith(Result<void> result) {
    when(
      () => repository.hardDelete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// The listing behind the detail is reloaded after a deletion; what it
  /// answers does not matter here, only that it answers.
  void answerListWith() {
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<envelope.Page<GoogleUser>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockGoogleUserRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAGoogleUser_WhenOpened_ThenTheRecordIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('1234567890'), findsOneWidget);
  });

  // AF-28e — nothing here is editable, and the screen says why.
  testWidgets('GivenAGoogleUser_WhenOpened_ThenNothingIsEditable', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.byType(TextFormField), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsNothing);
  });

  testWidgets('GivenAGoogleUser_WhenOpened_ThenTheReadOnlyReasonIsGiven', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(
      find.textContaining('come from Google and cannot be changed here'),
      findsOneWidget,
    );
  });

  // AF-28d — no picture, so the initials stand in.
  testWidgets('GivenNoPicture_WhenOpened_ThenInitialsAreShown', (tester) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('GivenAMissingGoogleUser_WhenOpened_ThenNotFoundIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Google user not found'), findsOneWidget);
  });

  testWidgets('GivenAMissingGoogleUser_WhenBackTapped_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
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

  testWidgets('GivenAForbiddenGoogleUser_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  testWidgets('GivenADeletedGoogleUser_WhenOpened_ThenItIsMarkedDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This Google user is deleted'), findsOneWidget);
  });

  testWidgets('GivenATransportFailure_WhenOpened_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('ada@example.com'), findsWidgets);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('ada@example.com'), findsWidgets);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheDetailIsStillShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Ada Lovelace'), findsWidgets);
  });

  testWidgets('GivenASystemAdmin_WhenOpened_ThenBothDeletionsAreOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Delete permanently'),
      findsOneWidget,
    );
  });

  // AF-29d — a Scope Admin never sees the permanent deletion.
  testWidgets('GivenAScopeAdmin_WhenOpened_ThenOnlyTheLogicalOneIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester, role: 2);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Delete permanently'),
      findsNothing,
    );
  });

  testWidgets('GivenADeletedGoogleUser_WhenOpened_ThenDeletionIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
      findsNothing,
    );
  });

  // AF-29e — deleting is not a way to keep somebody out, and the screen says
  // so before the dialog is even opened.
  testWidgets('GivenTheDangerZone_WhenRendered_ThenSignInAgainIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(
      find.textContaining('Neither stops them signing in again'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheDeleteControl_WhenTapped_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
    );

    // Then
    expect(find.text('Delete Ada Lovelace?'), findsOneWidget);
  });

  // AF-29e — and again in the dialog itself.
  testWidgets('GivenTheDeleteDialog_WhenOpened_ThenSignInAgainIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
    );

    // Then
    expect(find.textContaining('they can sign in again'), findsOneWidget);
  });

  testWidgets('GivenAConfirmedDeletion_WhenConfirmed_ThenTheyAreDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.delete(scopeId: 'scope-1', id: 'google-1'),
    ).called(1);
  });

  testWidgets('GivenADeletedGoogleUser_WhenDeleted_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
    answerDeleteWith(const Success<void>(null));
    answerListWith();
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  // AF-29a — the dialog closes and nothing is sent.
  testWidgets('GivenTheDeleteDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
    answerDeleteWith(const Success<void>(null));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
    );

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.delete(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
      ),
    );
  });

  // AF-29b — the API refused, and the record stays open.
  testWidgets('GivenARefusedDeletion_WhenConfirmed_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
    answerDeleteWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That Google user cannot be deleted.'],
        ),
      ),
    );
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete Google user'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('That Google user cannot be deleted.'), findsOneWidget);
  });

  // AF-29c — the confirm control stays disabled until the address matches.
  testWidgets('GivenTheHardDeleteDialog_WhenOpened_ThenConfirmIsDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
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
    answerGetWith(const Success<GoogleUser>(_ada));
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

  testWidgets('GivenTheTypedEmail_WhenItMatches_ThenTheyAreErased', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));
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
    verify(
      () => repository.hardDelete(scopeId: 'scope-1', id: 'google-1'),
    ).called(1);
  });
}
