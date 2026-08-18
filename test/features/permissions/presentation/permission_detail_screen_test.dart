import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission.dart';
import 'package:heimdall_ui/features/permissions/domain/scope_permission_repository.dart';
import 'package:heimdall_ui/features/permissions/presentation/permission_detail_screen.dart';
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
  scopeId: 'scope-1',
);

const _deleted = ScopePermission(
  id: 'permission-1',
  name: 'read:invoices',
  description: 'May read invoices',
  scopeId: 'scope-1',
  isDeleted: true,
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
      initialLocation: '/scopes/scope-1/permissions/permission-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/permissions',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/permissions/:permissionId',
          builder: (context, state) => PermissionDetailScreen(
            scopeId: state.pathParameters['scopeId']!,
            permissionId: state.pathParameters['permissionId']!,
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

  void answerGetWith(Result<ScopePermission> result) {
    when(
      () => repository.getById(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerUpdateWith(Result<ScopePermission> result) {
    when(
      () => repository.update(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        includeAsJwtClaim: any(named: 'includeAsJwtClaim'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockScopePermissionRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAPermission_WhenOpened_ThenTheRecordIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextFormField, 'read:invoices'), findsOneWidget);
  });

  testWidgets('GivenAnEdit_WhenSaved_ThenTheNewValuesAreSent', (tester) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:all',
          description: 'May read invoices',
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'read:invoices'),
      'read:all',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.update(
        scopeId: 'scope-1',
        id: 'permission-1',
        name: 'read:all',
        description: 'May read invoices',
        includeAsJwtClaim: false,
      ),
    ).called(1);
  });

  // AF-26e — the tokens already issued are unchanged, and the confirmation
  // says so.
  testWidgets('GivenTheClaimFlagTurnedOn_WhenSaved_ThenTheEffectIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:invoices',
          description: 'May read invoices',
          includeAsJwtClaim: true,
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.textContaining('tokens already issued do not'), findsOneWidget);
  });

  testWidgets('GivenTheClaimFlagTurnedOff_WhenSaved_ThenTheEffectIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:invoices',
          description: 'May read invoices',
          scopeId: 'scope-1',
          includeAsJwtClaim: true,
        ),
      ),
    );
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:invoices',
          description: 'May read invoices',
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.textContaining('still carry it until they expire'),
      findsOneWidget,
    );
  });

  testWidgets('GivenOnlyANameChange_WhenSaved_ThenOnlySavedIsSaid', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const Success<ScopePermission>(
        ScopePermission(
          id: 'permission-1',
          name: 'read:all',
          description: 'May read invoices',
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'read:invoices'),
      'read:all',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Saved.'), findsOneWidget);
  });

  // AF-26a — no such permission.
  testWidgets('GivenAMissingPermission_WhenOpened_ThenNotFoundIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<ScopePermission>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Permission not found'), findsOneWidget);
  });

  testWidgets('GivenAMissingPermission_WhenBackTapped_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<ScopePermission>(
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

  // AF-26b — out of this role's reach.
  testWidgets('GivenAForbiddenPermission_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<ScopePermission>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  // AF-26c — the API's own errors, with the typed input kept.
  testWidgets('GivenARejectedUpdate_WhenSaved_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));
    answerUpdateWith(
      const FailureResult<ScopePermission>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A permission with that name already exists.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'read:invoices'),
      'read:all',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('A permission with that name already exists.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'read:all'), findsOneWidget);
  });

  // AF-26d — a deleted permission is shown, marked, and read-only.
  testWidgets('GivenADeletedPermission_WhenOpened_ThenItIsMarkedDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This permission is deleted'), findsOneWidget);
  });

  testWidgets('GivenADeletedPermission_WhenOpened_ThenSavingIsNotOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsNothing);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
  });

  testWidgets('GivenNoEdit_WhenRendered_ThenSaveIsDisabled', (tester) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));

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
    answerGetWith(const Success<ScopePermission>(_readInvoices));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.widgetWithText(TextFormField, 'read:invoices'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.widgetWithText(TextFormField, 'read:invoices'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheDetailIsStillShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<ScopePermission>(_readInvoices));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.widgetWithText(TextFormField, 'read:invoices'), findsOneWidget);
  });
}
