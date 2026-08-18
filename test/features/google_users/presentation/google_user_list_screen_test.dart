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
import 'package:heimdall_ui/features/google_users/presentation/google_user_list_screen.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

class _MockScopeRepository extends Mock implements ScopeRepository {}

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

const _ada = GoogleUser(
  id: 'google-1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  profilePictureUrl: 'https://example.invalid/ada.png',
);

const _withGoogle = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
);

const _withoutGoogle = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
);

envelope.Page<GoogleUser> _page({
  List<GoogleUser> items = const <GoogleUser>[_ada],
  int pageNumber = 1,
  int totalPages = 1,
}) => envelope.Page<GoogleUser>(
  items: items,
  pageNumber: pageNumber,
  pageSize: 20,
  totalItems: items.length,
  totalPages: totalPages,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockGoogleUserRepository googleUsers;
  late _MockScopeRepository scopes;
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
        googleUserRepositoryProvider.overrideWithValue(googleUsers),
        scopeRepositoryProvider.overrideWithValue(scopes),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/google-users',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes',
          builder: (context, state) => const Scaffold(body: Text('scopes')),
        ),
        GoRoute(
          path: '/scopes/:scopeId',
          builder: (context, state) => const Scaffold(body: Text('scope')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/google-users',
          builder: (context, state) =>
              GoogleUserListScreen(scopeId: state.pathParameters['scopeId']!),
        ),
        GoRoute(
          path: '/scopes/:scopeId/google-users/:googleUserId',
          builder: (context, state) => Scaffold(
            body: Text('detail ${state.pathParameters['googleUserId']}'),
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

  void answerListWith(Result<envelope.Page<GoogleUser>> result) {
    when(
      () => googleUsers.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        email: any(named: 'email'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerScopeWith(Result<Scope> result) {
    when(
      () => scopes.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    googleUsers = _MockGoogleUserRepository();
    scopes = _MockScopeRepository();
    store = InMemoryTokenStore();
    answerScopeWith(const Success<Scope>(_withGoogle));
  });

  testWidgets('GivenAPage_WhenOpened_ThenTheGoogleUsersAreListed', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  // AF-28d — a picture that cannot be fetched leaves the initials showing.
  testWidgets('GivenAnUnreachablePicture_WhenListed_ThenInitialsAreShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('GivenNoPicture_WhenListed_ThenInitialsAreShown', (tester) async {
    // Given
    answerListWith(
      Success<envelope.Page<GoogleUser>>(
        _page(
          items: const <GoogleUser>[
            GoogleUser(
              id: 'google-1',
              name: 'Ada Lovelace',
              email: 'ada@example.com',
            ),
          ],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('AL'), findsOneWidget);
  });

  // FR-UX-04 — a table when the window is wide, cards when it is not.
  testWidgets('GivenAnExpandedWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));

    // When
    await pump(tester, size: _expanded);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenListed_ThenCardsAreShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('GivenAGoogleUser_WhenTapped_ThenTheirDetailOpens', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));
    await pump(tester, size: _compact);

    // When
    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail google-1'), findsOneWidget);
  });

  // AF-28a — nobody has signed in yet, and the scope allows it.
  testWidgets('GivenNoneAndGoogleOn_WhenListed_ThenTheReasonIsExplained', (
    tester,
  ) async {
    // Given
    answerListWith(
      Success<envelope.Page<GoogleUser>>(_page(items: const <GoogleUser>[])),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('No Google users yet'), findsOneWidget);
    expect(find.textContaining('Nobody has yet'), findsOneWidget);
  });

  // AF-28a — the scope has the feature off, which is why nobody could have.
  testWidgets('GivenNoneAndGoogleOff_WhenListed_ThenTheScopeIsLinked', (
    tester,
  ) async {
    // Given
    answerListWith(
      Success<envelope.Page<GoogleUser>>(_page(items: const <GoogleUser>[])),
    );
    answerScopeWith(const Success<Scope>(_withoutGoogle));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('switched off, so nobody can'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Scope settings'), findsOneWidget);
  });

  testWidgets('GivenGoogleOff_WhenScopeSettingsTapped_ThenTheScopeOpens', (
    tester,
  ) async {
    // Given
    answerListWith(
      Success<envelope.Page<GoogleUser>>(_page(items: const <GoogleUser>[])),
    );
    answerScopeWith(const Success<Scope>(_withoutGoogle));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Scope settings'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('scope'), findsOneWidget);
  });

  // AF-28a — a search that matched nothing is not the same thing.
  testWidgets('GivenNoMatches_WhenSearched_ThenClearingIsOffered', (
    tester,
  ) async {
    // Given
    answerListWith(
      Success<envelope.Page<GoogleUser>>(_page(items: const <GoogleUser>[])),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextField, 'Search by name'),
      'nobody',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('No Google users matched'), findsOneWidget);
  });

  // AF-28b — the returned errors, with a retry.
  testWidgets('GivenARefusedListing_WhenOpened_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerListWith(
      const FailureResult<envelope.Page<GoogleUser>>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Page size is too large.'],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Page size is too large.'), findsOneWidget);
  });

  testWidgets('GivenATransportFailure_WhenOpened_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    answerListWith(
      const FailureResult<envelope.Page<GoogleUser>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  // AF-28c — a scope this admin does not own.
  testWidgets('GivenAForbiddenScope_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerListWith(
      const FailureResult<envelope.Page<GoogleUser>>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  testWidgets('GivenIncludeDeleted_WhenToggled_ThenTheFlagIsSent', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));
    await pump(tester);

    // When
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => googleUsers.list(
        scopeId: 'scope-1',
        name: '',
        email: '',
        includeDeleted: true,
        pageNumber: 1,
      ),
    ).called(1);
  });

  // AF-28e — there is nothing to create here, so nothing offers to.
  testWidgets('GivenTheListing_WhenRendered_ThenNoCreateControlIsShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('GivenTheDarkTheme_WhenListed_ThenTheGoogleUsersAreStillShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<GoogleUser>>(_page()));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
}
