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
import 'package:heimdall_ui/features/permissions/presentation/permission_create_screen.dart';
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

const _created = ScopePermission(
  id: 'permission-9',
  name: 'read:invoices',
  description: 'May read invoices',
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
      initialLocation: '/scopes/scope-1/permissions/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/permissions',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/permissions/new',
          builder: (context, state) =>
              PermissionCreateScreen(scopeId: state.pathParameters['scopeId']!),
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

  void answerCreateWith(Result<ScopePermission> result) {
    when(
      () => repository.create(
        scopeId: any(named: 'scopeId'),
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
    answerCreateWith(const Success<ScopePermission>(_created));
    when(
      () => repository.list(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        includeDeleted: any(named: 'includeDeleted'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const FailureResult<envelope.Page<ScopePermission>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
  });

  testWidgets('GivenACompleteForm_WhenSubmitted_ThenThePermissionIsCreated', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'read:invoices',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create permission'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.create(
        scopeId: 'scope-1',
        name: 'read:invoices',
        description: '',
        includeAsJwtClaim: false,
      ),
    ).called(1);
  });

  testWidgets('GivenACreatedPermission_WhenCreated_ThenItsDetailOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'read:invoices',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create permission'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('detail permission-9'), findsOneWidget);
  });

  testWidgets('GivenTheClaimSwitch_WhenSet_ThenItIsSent', (tester) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'read:invoices',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create permission'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.create(
        scopeId: 'scope-1',
        name: 'read:invoices',
        description: '',
        includeAsJwtClaim: true,
      ),
    ).called(1);
  });

  // AF-25d — what including the permission as a claim actually does.
  testWidgets('GivenTheForm_WhenRendered_ThenTheClaimEffectIsExplained', (
    tester,
  ) async {
    // Given / When
    await pump(tester);

    // Then
    expect(
      find.textContaining('Every token this scope issues from now on'),
      findsOneWidget,
    );
  });

  // AF-25a — an empty name never reaches the API.
  testWidgets('GivenNoName_WhenSubmitted_ThenNoRequestIsMade', (tester) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create permission'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.create(
        scopeId: any(named: 'scopeId'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        includeAsJwtClaim: any(named: 'includeAsJwtClaim'),
      ),
    );
  });

  // AF-25b — a duplicate name, in the API's own words.
  testWidgets('GivenADuplicateName_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<ScopePermission>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['A permission with that name already exists.'],
        ),
      ),
    );
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'read:invoices',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create permission'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('A permission with that name already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenARejectedCreate_WhenSubmitted_ThenTheInputIsKept', (
    tester,
  ) async {
    // Given
    answerCreateWith(
      const FailureResult<ScopePermission>(
        Failure(kind: FailureKind.validation, errors: <String>['No.']),
      ),
    );
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'read:invoices',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Create permission'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextFormField, 'read:invoices'), findsOneWidget);
  });

  // AF-25c — leaving a modified form asks first.
  testWidgets('GivenAModifiedForm_WhenCancelled_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'read:invoices',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Discard this permission?'), findsOneWidget);
  });

  testWidgets('GivenAModifiedForm_WhenDiscardConfirmed_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'read:invoices',
    );
    await tester.pumpAndSettle();
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
    // Given / When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('Create a permission'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Create a permission'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheFormIsStillShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Create a permission'), findsOneWidget);
  });
}
