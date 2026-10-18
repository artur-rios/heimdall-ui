import 'dart:async';
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
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/home/presentation/home_screen.dart';
import 'package:heimdall_ui/features/persons/domain/person.dart';
import 'package:heimdall_ui/features/scope_invitations/domain/scope_invitation.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/shared/widgets/notice_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/dashboard_fakes.dart';

/// A token naming a person of [role]: 1 System Admin, 2 Scope Admin, 3 User.
///
/// A Google sign-in's token names a Google User instead, in its scope.
String _jwt({int role = 1, bool viaGoogle = false}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': viaGoogle ? 'google-1' : 'person-1',
        'name': 'Ada',
        'role': role,
        if (viaGoogle) 'scopeId': 'scope-1',
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

const _grace = GoogleUser(
  id: 'google-1',
  name: 'Grace Hopper',
  email: 'grace@example.com',
  scopeId: 'scope-1',
);

final _initechInvitation = ScopeInvitation(
  id: 'invitation-1',
  scopeId: 'scope-9',
  scopeName: 'Initech',
  invitedByName: 'Ada',
  expiresAt: DateTime.utc(2026, 10, 23, 9),
);

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
    bool viaGoogle = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: _jwt(role: role, viaGoogle: viaGoogle),
        expiresAt: DateTime.utc(2030),
        viaGoogle: viaGoogle,
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
          '/system-admins',
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

  testWidgets(
    'GivenASystemAdmin_WhenHomeOpens_ThenTheSystemAdminsTileShowsTheCount',
    (tester) async {
      // Given three System Admins
      final fakes = FakeDashboardRepositories(systemAdmins: 3);

      // When
      await pump(tester, fakes: fakes);

      // Then
      expect(find.text('System Admins'), findsOneWidget);
      expect(find.text('Full access to every scope'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    },
  );

  testWidgets('GivenTheSystemAdminsTile_WhenTapped_ThenTheListOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.text('System Admins'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('opened /system-admins'), findsOneWidget);
  });

  testWidgets('GivenTheCountFails_WhenHomeOpens_ThenTheTileStillOpensTheList', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(systemAdmins: null);

    // When
    await pump(tester, fakes: fakes);

    // Then
    expect(find.byTooltip('Could not be read'), findsWidgets);

    await tester.tap(find.text('System Admins'));
    await tester.pumpAndSettle();
    expect(find.text('opened /system-admins'), findsOneWidget);
  });

  testWidgets('GivenAScopeAdmin_WhenHomeOpens_ThenNoSystemAdminsTile', (
    tester,
  ) async {
    // Given a Scope Admin

    // When
    await pump(tester, role: 2);

    // Then
    expect(find.text('System Admins'), findsNothing);
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

  // #133 — a Google User's own account is their Google record. A second
  // factor does not apply to them, so it is not offered as "not set up".
  testWidgets('GivenAGoogleUser_WhenOpened_ThenTheirGoogleAccountIsShown', (
    tester,
  ) async {
    // Given
    final fakes = FakeDashboardRepositories(googleMe: _grace);

    // When
    await pump(tester, fakes: fakes, role: 3, viaGoogle: true);

    // Then
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('grace@example.com'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Signs in with Google'), findsOneWidget);
    expect(find.text('Not set up'), findsNothing);
    expect(
      find.text('Your account details could not be read just now.'),
      findsNothing,
    );
  });

  for (final (label, size, dark) in <(String, Size, bool)>[
    ('Compact', _compact, false),
    ('Dark', _expanded, true),
  ]) {
    testWidgets('Given${label}GoogleHome_WhenRendered_ThenNothingOverflows', (
      tester,
    ) async {
      // Given
      final fakes = FakeDashboardRepositories(googleMe: _grace);

      // When
      await pump(
        tester,
        fakes: fakes,
        role: 3,
        viaGoogle: true,
        size: size,
        theme: dark ? buildDarkTheme() : null,
      );

      // Then
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('GivenOpenInvitations_WhenHomeIsShown_ThenTheCardListsThem', (
    tester,
  ) async {
    // Given a Scope Admin with one open invitation
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme],
      invitations: <ScopeInvitation>[_initechInvitation],
    );

    // When Home is shown
    await pump(tester, fakes: fakes, role: 2);

    // Then the card lists it
    expect(find.text('Scope invitations'), findsOneWidget);
    expect(find.text('Initech'), findsOneWidget);
    expect(find.textContaining('Invited by Ada'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('GivenNoInvitations_WhenHomeIsShown_ThenNoCardIsShown', (
    tester,
  ) async {
    // Given no open invitation (AF-39a)
    final fakes = FakeDashboardRepositories(scopes: const <Scope>[_acme]);

    // When Home is shown
    await pump(tester, fakes: fakes, role: 2);

    // Then no card is shown
    expect(find.text('Scope invitations'), findsNothing);
  });

  testWidgets(
    'GivenAnInvitation_WhenAcceptConfirmed_ThenItIsSentAndTheCardSaysSo',
    (tester) async {
      // Given an open invitation and the accept dialog
      final fakes = FakeDashboardRepositories(
        scopes: const <Scope>[_acme],
        invitations: <ScopeInvitation>[_initechInvitation],
      );
      await pump(tester, fakes: fakes, role: 2);
      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Accept the invitation to Initech?'), findsOneWidget);

      // When the answer is confirmed
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Accept'),
        ),
      );
      await tester.pumpAndSettle();

      // Then it is sent and the card says so, through the shared banner
      expect(fakes.accepted, <String>['invitation-1']);
      expect(
        find.descendant(
          of: find.byType(NoticeBanner),
          matching: find.text('Invitation accepted. You now co-own Initech.'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenAnAcceptInFlight_WhenHomeIsLeft_ThenItsAnswerTouchesNoDisposedHome',
    (tester) async {
      // Given an acceptance held back by the API
      final hold = Completer<void>();
      final fakes = FakeDashboardRepositories(
        scopes: const <Scope>[_acme],
        invitations: <ScopeInvitation>[_initechInvitation],
        acceptHeldUntil: hold.future,
      );
      await pump(tester, fakes: fakes, role: 2);
      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Accept'),
        ),
      );
      await tester.pumpAndSettle();

      // When Home is left before the answer arrives
      GoRouter.of(tester.element(find.byType(HomeScreen))).go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('opened /profile'), findsOneWidget);
      hold.complete();
      await tester.pumpAndSettle();

      // Then the answer lands without reaching the disposed Home
      expect(fakes.accepted, <String>['invitation-1']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GivenTheDeclineDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given the decline dialog is open (AF-39b)
    final fakes = FakeDashboardRepositories(
      scopes: const <Scope>[_acme],
      invitations: <ScopeInvitation>[_initechInvitation],
    );
    await pump(tester, fakes: fakes, role: 2);
    await tester.tap(find.widgetWithText(TextButton, 'Decline'));
    await tester.pumpAndSettle();

    // When it is cancelled
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then nothing is sent
    expect(fakes.declined, isEmpty);
    expect(find.text('Initech'), findsOneWidget);
  });

  testWidgets(
    'GivenOpenInvitations_WhenShownOnACompactWindow_ThenBothAnswersFit',
    (tester) async {
      // Given an open invitation
      final fakes = FakeDashboardRepositories(
        scopes: const <Scope>[_acme],
        invitations: <ScopeInvitation>[_initechInvitation],
      );

      // When Home is shown on a compact window
      await pump(tester, fakes: fakes, role: 2, size: _compact);

      // Then no overflow error, and both controls are on screen
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Decline'), findsOneWidget);
    },
  );
}
