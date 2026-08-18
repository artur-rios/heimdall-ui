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
import 'package:heimdall_ui/features/permissions/domain/scope_permission.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission_repository.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_list_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockScopePermissionRepository extends Mock
    implements ScopePermissionRepository {}

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

const _readInvoices = ScopePermission(
  id: 'permission-1',
  name: 'read:invoices',
  description: 'May read invoices',
  includeAsJwtClaim: true,
);

envelope.Page<ScopePermission> _page({
  List<ScopePermission> items = const <ScopePermission>[_readInvoices],
  int pageNumber = 1,
  int totalPages = 1,
}) => envelope.Page<ScopePermission>(
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
  late _MockScopePermissionRepository repository;
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
        scopePermissionRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/permissions',
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
          path: '/scopes/:scopeId/permissions',
          builder: (context, state) =>
              PermissionListScreen(scopeId: state.pathParameters['scopeId']!),
        ),
        GoRoute(
          path: '/scopes/:scopeId/permissions/new',
          builder: (context, state) => const Scaffold(body: Text('create')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/permissions/:permissionId',
          builder: (context, state) => Scaffold(
            body: Text('detail ${state.pathParameters['permissionId']}'),
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

  void answerWith(Result<envelope.Page<ScopePermission>> result) {
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockScopePermissionRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAPage_WhenOpened_ThenThePermissionsAreListed', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('read:invoices'), findsOneWidget);
  });

  // FR-PM-04 — a permission issued in the scope's tokens says so.
  testWidgets('GivenAClaimPermission_WhenListed_ThenItSaysItIsInTokens', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('Yes'), findsOneWidget);
  });

  // FR-UX-04 — a table when the window is wide, cards when it is not.
  testWidgets('GivenAnExpandedWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));

    // When
    await pump(tester, size: _expanded);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenListed_ThenATableIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenListed_ThenCardsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('GivenAPermission_WhenTapped_ThenItsDetailOpens', (tester) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));
    await pump(tester, size: _compact);

    // When
    await tester.tap(find.text('read:invoices'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail permission-1'), findsOneWidget);
  });

  // AF-24a — none yet, which offers UI-25.
  testWidgets('GivenNoneAndNoFilter_WhenListed_ThenCreateIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      Success<envelope.Page<ScopePermission>>(
        _page(items: const <ScopePermission>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('No permissions yet'), findsOneWidget);
  });

  // AF-24a — no matches, which offers to clear the filter.
  testWidgets('GivenNoMatches_WhenSearched_ThenClearingIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      Success<envelope.Page<ScopePermission>>(
        _page(items: const <ScopePermission>[]),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('No permissions matched'), findsOneWidget);
  });

  // AF-24b — the returned errors, with a retry.
  testWidgets('GivenARefusedListing_WhenOpened_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<ScopePermission>>(
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
      const FailureResult<envelope.Page<ScopePermission>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  // AF-24c — a scope this admin does not own.
  testWidgets('GivenAForbiddenScope_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<ScopePermission>>(
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
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));
    await pump(tester);

    // When
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.list(
        scopeId: 'scope-1',
        name: '',
        includeDeleted: true,
        pageNumber: 1,
      ),
    ).called(1);
  });

  testWidgets('GivenTheCreateControl_WhenTapped_ThenTheFormOpens', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));
    await pump(tester);

    // When
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'New permission'),
    );
    await tester.pumpAndSettle();

    // Then
    expect(find.text('create'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenListed_ThenThePermissionsAreStillShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<ScopePermission>>(_page()));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('read:invoices'), findsOneWidget);
  });
}
