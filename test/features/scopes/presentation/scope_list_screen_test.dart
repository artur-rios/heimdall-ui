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
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

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
  ownerIds: <String>['person-1', 'person-2'],
);

envelope.Page<Scope> _page({
  List<Scope> items = const <Scope>[_acme],
  int pageNumber = 1,
  int totalPages = 1,
}) => envelope.Page<Scope>(
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
  late _MockScopeRepository repository;
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
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes',
          builder: (context, state) => const ScopeListScreen(),
        ),
        GoRoute(
          path: '/scopes/new',
          builder: (context, state) => const Scaffold(body: Text('create')),
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

  void answerWith(Result<envelope.Page<Scope>> result) {
    when(
      () => repository.list(
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockScopeRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAPageOfScopes_WhenOpened_ThenTheScopesAreListed', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('Acme'), findsOneWidget);
  });

  // FR-UX-04 — a table when the window is wide.
  testWidgets('GivenAnExpandedWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));

    // When
    await pump(tester, size: _expanded);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  // FR-UX-04 — cards when it is not.
  testWidgets('GivenACompactWindow_WhenListed_ThenCardsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('GivenAScope_WhenTapped_ThenItsDetailOpens', (tester) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));
    await pump(tester, size: _compact);

    // When
    await tester.tap(find.text('Acme'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail scope-1'), findsOneWidget);
  });

  // AF-10a — nothing here yet, which offers UI-11.
  testWidgets('GivenNoScopesAndNoFilter_WhenListed_ThenCreateIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page(items: const <Scope>[])));

    // When
    await pump(tester);

    // Then
    expect(find.text('No scopes yet'), findsOneWidget);
  });

  // AF-10a — no matches, which offers to clear the filter.
  testWidgets('GivenNoMatches_WhenSearched_ThenClearingIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page(items: const <Scope>[])));
    await pump(tester);

    // When
    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('No scopes matched'), findsOneWidget);
  });

  testWidgets('GivenNoMatches_WhenFiltersCleared_ThenTheFullListingIsRead', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page(items: const <Scope>[])));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Clear filters'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.list(name: '', includeDeleted: false, pageNumber: 1),
    ).called(greaterThanOrEqualTo(1));
  });

  // AF-10b — the returned errors, with a retry that keeps the filters.
  testWidgets('GivenARefusedListing_WhenOpened_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<Scope>>(
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
    answerWith(
      const FailureResult<envelope.Page<Scope>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenAFailedSearch_WhenRetried_ThenTheSameQueryIsSent', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<Scope>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Acme');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.list(name: 'Acme', includeDeleted: false, pageNumber: 1),
    ).called(2);
  });

  // AF-10c — only a System Admin may create a scope.
  testWidgets('GivenASystemAdmin_WhenListed_ThenCreateIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));

    // When
    await pump(tester, role: 1);

    // Then
    expect(
      find.widgetWithText(FloatingActionButton, 'New scope'),
      findsOneWidget,
    );
  });

  testWidgets('GivenAScopeAdmin_WhenListed_ThenCreateIsHidden', (tester) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));

    // When
    await pump(tester, role: 2);

    // Then
    expect(
      find.widgetWithText(FloatingActionButton, 'New scope'),
      findsNothing,
    );
  });

  testWidgets('GivenAScopeAdminAndNoScopes_WhenListed_ThenCreateIsNotOffered', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page(items: const <Scope>[])));

    // When
    await pump(tester, role: 2);

    // Then
    expect(find.widgetWithText(FilledButton, 'New scope'), findsNothing);
  });

  testWidgets('GivenIncludeDeleted_WhenToggled_ThenTheFlagIsSent', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));
    await pump(tester);

    // When
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.list(name: '', includeDeleted: true, pageNumber: 1),
    ).called(1);
  });

  testWidgets('GivenSeveralPages_WhenNextTapped_ThenTheNextPageIsRead', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page(totalPages: 3)));
    await pump(tester);

    // When
    await tester.tap(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.list(name: '', includeDeleted: false, pageNumber: 2),
    ).called(1);
  });

  testWidgets('GivenTheFirstPage_WhenRendered_ThenPreviousIsDisabled', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page(totalPages: 3)));

    // When
    await pump(tester);

    // Then
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.chevron_left),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenTheDarkTheme_WhenListed_ThenTheScopesAreStillShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<Scope>>(_page()));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Acme'), findsOneWidget);
  });
}
