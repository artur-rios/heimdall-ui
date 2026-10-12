import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/home/presentation/home_screen.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/dashboard_fakes.dart';

/// A token naming a person of [role]: 1 System Admin, 2 Scope Admin, 3 User.
String _jwt({int role = 1}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'name': 'Ada',
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
);

const _globex = Scope(id: 'scope-2', name: 'Globex', description: '');

const Size _compact = Size(400, 1400);
const Size _expanded = Size(1400, 1400);

void main() {
  late InMemoryTokenStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = InMemoryTokenStore();
  });

  Future<void> pump(
    WidgetTester tester, {
    FakeDashboardRepositories? fakes,
    int role = 1,
    Size size = _expanded,
    ThemeData? theme,
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

    final container = ProviderContainer(
      overrides: <Override>[
        ...(fakes ?? FakeDashboardRepositories()).overrides,
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        for (final path in <String>[
          '/scopes',
          '/scopes/:scopeId',
          '/profile',
          '/profile/security',
          '/health',
        ])
          GoRoute(
            path: path,
            builder: (context, state) =>
                Scaffold(body: Text('opened ${state.uri.path}')),
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

  testWidgets('GivenASystemAdmin_WhenOpened_ThenTheFiguresAreShown', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme, _globex],
      deletedScopes: 1,
      persons: 3,
      applications: 2,
      permissions: 4,
      googleUsers: 5,
    );

    // When
    await pump(tester, fakes: fakes);

    // Then
    expect(find.text('Welcome back, Ada'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Active, 1 deleted'), findsOneWidget);
    expect(find.text('6'), findsOneWidget); // persons
    expect(find.text('8'), findsOneWidget); // permissions
    expect(find.text('10'), findsOneWidget); // Google users
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('GivenScopes_WhenOpened_ThenEachIsBrokenDown', (tester) async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme],
      persons: 1,
      applications: 2,
    );

    // When
    await pump(tester, fakes: fakes);

    // Then
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('1 person'), findsOneWidget);
    expect(find.text('2 applications'), findsOneWidget);
    expect(find.text('Google Sign-In on'), findsOneWidget);
  });

  testWidgets('GivenAScopeRow_WhenTapped_ThenTheScopeOpens', (tester) async {
    // Given
    await pump(
      tester,
      fakes: FakeDashboardRepositories(scopes: const <Scope>[_acme]),
    );

    // When
    await tester.tap(find.text('Acme'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('opened /scopes/scope-1'), findsOneWidget);
  });

  testWidgets('GivenTheScopesTile_WhenTapped_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    await pump(
      tester,
      fakes: FakeDashboardRepositories(scopes: const <Scope>[_acme]),
    );

    // When
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('opened /scopes'), findsOneWidget);
  });

  testWidgets('GivenAnUnreadableCount_WhenOpened_ThenItIsShownAsUnknown', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme],
      permissions: null,
    );

    // When
    await pump(tester, fakes: fakes);

    // Then
    expect(find.text('—'), findsOneWidget);
    expect(find.text('— permissions'), findsOneWidget);
  });

  testWidgets('GivenUnreadableScopes_WhenOpened_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopesFailure: const Failure(
        kind: FailureKind.server,
        errors: <String>['Scopes are unavailable.'],
      ),
    );

    // When
    await pump(tester, fakes: fakes);

    // Then
    expect(find.text('Scopes are unavailable.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenAnUnreachableApi_WhenOpened_ThenItSaysSo', (tester) async {
    // Given
    final fakes = FakeDashboardRepositories(apiReachable: false);

    // When
    await pump(tester, fakes: fakes);

    // Then
    expect(find.text('Unreachable'), findsOneWidget);
  });

  testWidgets('GivenNoScopes_WhenASystemAdminOpens_ThenTheFirstIsInvited', (
    tester,
  ) async {
    // Given no scopes at all

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('Create the first one'), findsOneWidget);
    expect(find.text('New scope'), findsOneWidget);
  });

  testWidgets('GivenAScopeAdmin_WhenOpened_ThenNoScopeCreationIsOffered', (
    tester,
  ) async {
    // Given no owned scopes

    // When
    await pump(tester, role: 2);

    // Then
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('New scope'), findsNothing);
    expect(find.textContaining('You do not own any scopes'), findsOneWidget);
  });

  testWidgets('GivenAUser_WhenOpened_ThenOnlyTheirAccountIsShown', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(
      me: const Person(
        id: 'person-1',
        name: 'Ada',
        email: 'ada@example.com',
        role: Role.user,
        twoFactorEnabled: true,
      ),
    );

    // When
    await pump(tester, fakes: fakes, role: 3);

    // Then
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Protected'), findsOneWidget);
  });

  testWidgets('GivenAnUnprotectedAccount_WhenOpened_ThenItIsFlagged', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(
      me: const Person(
        id: 'person-1',
        name: 'Ada',
        email: 'ada@example.com',
        role: Role.user,
        emailVerified: false,
      ),
    );

    // When
    await pump(tester, fakes: fakes, role: 3);

    // Then
    expect(find.text('Not verified'), findsOneWidget);
    expect(find.text('Not set up'), findsOneWidget);
  });

  testWidgets('GivenTheSecurityShortcut_WhenTapped_ThenSecurityOpens', (
    tester,
  ) async {
    // Given
    await pump(tester, role: 3);

    // When
    await tester.tap(find.widgetWithText(OutlinedButton, 'Security'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('opened /profile/security'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenNothingOverflows', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme, _globex],
    );

    // When
    await pump(tester, fakes: fakes, size: _compact);

    // Then
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheDashboardIsShown', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(scopes: const <Scope>[_acme]);

    // When
    await pump(tester, fakes: fakes, theme: buildDarkTheme());

    // Then
    expect(find.text('Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
