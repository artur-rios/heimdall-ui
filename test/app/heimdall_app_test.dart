import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/app_version.dart';
import 'package:heimdall_ui/app/heimdall_app.dart';
import 'package:heimdall_ui/app/router.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights.dart';
import 'package:heimdall_ui/features/data_rights/domain/data_rights_repository.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/erasure_request_repository.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';
import 'package:heimdall_ui/features/erasure_requests/presentation/erasure_request_list_controller.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/home/presentation/dashboard_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/profile_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/dashboard_fakes.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockErasureRequestRepository extends Mock
    implements ErasureRequestRepository {}

class _MockDataRightsRepository extends Mock implements DataRightsRepository {}

class _MockGoogleSignInGateway extends Mock implements GoogleSignInGateway {}

const String _systemAdminJwt =
    'header.'
    'eyJzdWIiOiI2ZjFkM2EwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDEiLCJlbWFpbCI6'
    'ImFkbWluQGV4YW1wbGUuY29tIiwicm9sZSI6MX0.'
    'signature';

void main() {
  late InMemoryTokenStore store;
  late _MockAuthRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = InMemoryTokenStore();
    repository = _MockAuthRepository();
    // The privacy notice is a bundled asset, and rootBundle would otherwise
    // hand a later test the load of an earlier one, whose clock has stopped.
    rootBundle.clear();
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const <Override>[],
    FakeDashboardRepositories? fakes,
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        ...(fakes ?? FakeDashboardRepositories()).overrides,
        // The sign-in screen asks the configuration whether to offer the
        // Google control, so the whole app needs one to render.
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:8080'),
        ),
        tokenStoreProvider.overrideWithValue(store),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        authRepositoryProvider.overrideWithValue(repository),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeimdallApp(),
      ),
    );
    await tester.pumpAndSettle();

    return container;
  }

  testWidgets('GivenNoSession_WhenAppStarts_ThenLoginScreenIsShown', (
    tester,
  ) async {
    // Given no stored token

    // When
    await pumpApp(tester);

    // Then
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('GivenStoredSession_WhenAppStarts_ThenHomeScreenIsShown', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );

    // When
    await pumpApp(tester);

    // Then
    expect(find.text('Welcome back, admin@example.com'), findsOneWidget);
    expect(find.text('System Admin'), findsWidgets);
  });

  // Home is where a User's own settings are reached from, as well as the
  // navigation. The API's token names them in `name` and carries no address.
  testWidgets('GivenAUserSession_WhenAppStarts_ThenTheirProfileIsOffered', (
    tester,
  ) async {
    // Given
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode(<String, String>{
              'id': '6f1d3a00-0000-0000-0000-000000000003',
              'role': '3',
              'name': 'Ada Lovelace',
            }),
          ),
        )
        .replaceAll('=', '');
    await store.write(
      AuthToken(
        value: 'header.$payload.signature',
        expiresAt: DateTime.utc(2030),
      ),
    );

    // When
    await pumpApp(tester);

    // Then
    expect(find.text('Welcome back, Ada Lovelace'), findsOneWidget);
    expect(find.text('Your profile'), findsWidgets);
  });

  // #133 — a Google sign-in's subject is a Google User, which the persons
  // endpoint answers `404` for. Home reads the Google User's own record
  // instead, so the session is not mistaken for a deleted account and ended.
  testWidgets('GivenAGoogleSession_WhenAppStarts_ThenItStaysSignedIn', (
    tester,
  ) async {
    // Given
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode(<String, String>{
              'id': '6f1d3a00-0000-0000-0000-000000000004',
              'role': '3',
              'scopeId': '6f1d3a00-0000-0000-0000-0000000000aa',
              'name': 'Grace Hopper',
            }),
          ),
        )
        .replaceAll('=', '');
    await store.write(
      AuthToken(
        value: 'header.$payload.signature',
        expiresAt: DateTime.utc(2030),
        viaGoogle: true,
      ),
    );
    final fakes = FakeDashboardRepositories(
      googleMe: const GoogleUser(
        id: '6f1d3a00-0000-0000-0000-000000000004',
        name: 'Grace Hopper',
        email: 'grace@example.com',
        scopeId: '6f1d3a00-0000-0000-0000-0000000000aa',
      ),
    );
    // Were the session ended, it would sign out of Google too.
    final google = _MockGoogleSignInGateway();
    when(google.signOut).thenAnswer((_) async {});

    // When
    final container = await pumpApp(
      tester,
      fakes: fakes,
      overrides: <Override>[
        googleSignInGatewayProvider.overrideWithValue(google),
      ],
    );

    // Then
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
    expect(
      container.read(profileControllerProvider),
      isA<GoogleProfileLoaded>(),
    );
    expect(find.text('Welcome back, Grace Hopper'), findsOneWidget);
    expect(find.text('grace@example.com'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('GivenEmptyPassword_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Enter your password.'), findsOneWidget);
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('GivenRejectedLogin_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'wrong')).thenAnswer(
      (_) async => const FailureResult<LoginOutcome>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Invalid credentials'],
        ),
      ),
    );
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrong',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('GivenAcceptedLogin_WhenSubmitted_ThenHomeScreenIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(
        LoggedIn(
          AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
        ),
      ),
    );
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Welcome back, admin@example.com'), findsOneWidget);
  });

  // AF-07c — a slow read of the stored token must not bounce a returning user
  // to sign-in; they wait instead.
  testWidgets('GivenASlowTokenRead_WhenAppStarts_ThenALoadingStateIsShown', (
    tester,
  ) async {
    // Given
    final slow = _SlowTokenStore(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...FakeDashboardRepositories().overrides,
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:8080'),
        ),
        tokenStoreProvider.overrideWithValue(slow),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    // When
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeimdallApp(),
      ),
    );
    await tester.pump();

    // Then
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    slow.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('GivenASlowTokenRead_WhenItCompletes_ThenTheSessionIsRestored', (
    tester,
  ) async {
    // Given
    final slow = _SlowTokenStore(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...FakeDashboardRepositories().overrides,
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:8080'),
        ),
        tokenStoreProvider.overrideWithValue(slow),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeimdallApp(),
      ),
    );
    await tester.pump();

    // When
    slow.finish();
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Welcome back, admin@example.com'), findsOneWidget);
  });

  // AF-07d — a role that is not offered a screen is told so, and is not
  // bounced somewhere it did not ask for.
  testWidgets('GivenAUser_WhenVisitingAnAdminRoute_ThenTheRefusalIsShown', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _userJwt(), expiresAt: DateTime.utc(2030)),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...FakeDashboardRepositories().overrides,
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:8080'),
        ),
        tokenStoreProvider.overrideWithValue(store),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeimdallApp(),
      ),
    );
    await tester.pumpAndSettle();

    // When
    container.read(routerProvider).go('/scopes');
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  // Issue #73: the login screen links the notice, and following the link
  // must not bounce a signed-out visitor back to sign-in.
  testWidgets(
    'GivenNoSession_WhenThePrivacyLinkIsTapped_ThenTheNoticeIsShown',
    (tester) async {
      // Given
      await pumpApp(tester);

      // When
      await tester.tap(find.widgetWithText(TextButton, 'Privacy notice'));
      await tester.pumpAndSettle();

      // Then
      expect(find.widgetWithText(AppBar, 'Privacy notice'), findsOneWidget);
      expect(
        find.textContaining('Who is responsible', findRichText: true),
        findsOneWidget,
      );
    },
  );

  // Issue #73: Google's consent screen opens the address itself.
  testWidgets(
    'GivenNoSession_WhenPrivacyIsOpenedDirectly_ThenTheNoticeIsShown',
    (tester) async {
      // Given
      final container = await pumpApp(tester);

      // When
      container.read(routerProvider).go('/privacy');
      await tester.pumpAndSettle();

      // Then
      expect(find.widgetWithText(AppBar, 'Privacy notice'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets('GivenASession_WhenPrivacyIsOpened_ThenTheNoticeIsShown', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final container = await pumpApp(tester);

    // When
    container.read(routerProvider).go('/privacy');
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(AppBar, 'Privacy notice'), findsOneWidget);
  });

  // AF-07e — a token rejected mid-session ends it and says why.
  testWidgets('GivenARejectedToken_WhenTheSessionEnds_ThenTheReasonIsShown', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...FakeDashboardRepositories().overrides,
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:8080'),
        ),
        tokenStoreProvider.overrideWithValue(store),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeimdallApp(),
      ),
    );
    await tester.pumpAndSettle();

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signOut(expired: true);
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text(
        'Your session ended. Sign in again to pick up where you left off.',
      ),
      findsOneWidget,
    );
  });

  // Signing out deliberately is not a session that ended under the caller.
  testWidgets('GivenADeliberateSignOut_WhenSignedOut_ThenNoReasonIsShown', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...FakeDashboardRepositories().overrides,
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:8080'),
        ),
        tokenStoreProvider.overrideWithValue(store),
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeimdallApp(),
      ),
    );
    await tester.pumpAndSettle();

    // When
    await container.read(sessionControllerProvider.notifier).signOut();
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.text(
        'Your session ended. Sign in again to pick up where you left off.',
      ),
      findsNothing,
    );
  });

  // UI-30 main flow — AF-11i: the sign-in answers with a restricted token, and
  // the person lands on the only screen it can use.
  testWidgets('GivenARestrictedLogin_WhenSubmitted_ThenTheRestrictionIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(
        LoggedIn(
          AuthToken(
            value: _systemAdminJwt,
            expiresAt: DateTime.utc(2030),
            processingRestricted: true,
          ),
        ),
      ),
    );
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('Processing of your account is restricted'),
      findsOneWidget,
    );
    expect(find.text('Signed in as admin@example.com'), findsOneWidget);
  });

  // UI-30 AF-30a — a session restored from storage is read from its claim.
  testWidgets('GivenAStoredRestrictedToken_WhenAppStarts_ThenItIsRestricted', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _restrictedJwt(), expiresAt: DateTime.utc(2030)),
    );

    // When
    final container = await pumpApp(tester);
    container.read(routerProvider).go('/scopes');
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('Processing of your account is restricted'),
      findsOneWidget,
    );
  });

  // UI-30 — after lifting, the sign-in screen says why the person is there.
  testWidgets('GivenALiftedRestriction_WhenSignedOut_ThenTheReasonIsShown', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _restrictedJwt(), expiresAt: DateTime.utc(2030)),
    );
    final container = await pumpApp(tester);

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signOut(restrictionLifted: true);
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text(
        'The restriction on processing your account is lifted. Sign in again '
        'for full access.',
      ),
      findsOneWidget,
    );
  });

  // UI-33 — restricted from the profile, then signed out, and the sign-in
  // screen says what signing in again leads to.
  testWidgets('GivenAProfile_WhenProcessingIsRestricted_ThenTheNoteIsShown', (
    tester,
  ) async {
    // Given
    final dataRights = _MockDataRightsRepository();
    when(
      () =>
          dataRights.restrictProcessing(RestrictionGround.neededForLegalClaim),
    ).thenAnswer((_) async => const Success<void>(null));
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final container = await pumpApp(
      tester,
      overrides: <Override>[
        dataRightsRepositoryProvider.overrideWithValue(dataRights),
      ],
    );
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    final entry = find.text('Restrict processing of my account');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final ground = find.text(
      'Heimdall no longer needs my data, but I need it kept for a legal claim',
    );
    await tester.ensureVisible(ground);
    await tester.pumpAndSettle();
    await tester.tap(ground);
    await tester.pump();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Restrict processing'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(
      find.text(
        'Processing of your account is restricted, and your account is '
        'suspended until the restriction is lifted. Sign in again to lift it, '
        'or to download or erase your data.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  // The next person to sign in on this device may be somebody else, so what
  // the last session was shown is forgotten when it ends.
  testWidgets('GivenASignedInDashboard_WhenSignedOut_ThenItIsForgotten', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );
    final container = await pumpApp(tester);
    expect(container.read(dashboardControllerProvider), isA<DashboardLoaded>());
    expect(container.read(profileControllerProvider), isA<ProfileLoaded>());

    // When
    await container.read(sessionControllerProvider.notifier).signOut();
    await tester.pumpAndSettle();

    // Then
    expect(
      container.read(dashboardControllerProvider),
      isA<DashboardLoading>(),
    );
    expect(container.read(profileControllerProvider), isA<ProfileLoading>());
  });

  testWidgets(
    'GivenAnErasureListing_WhenSignedOut_ThenItsFilterAndPageAreForgotten',
    (tester) async {
      // Given
      final erasures = _MockErasureRequestRepository();
      when(
        () => erasures.list(
          overdueOnly: any(named: 'overdueOnly'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => const Success<envelope.Page<OutstandingErasure>>(
          envelope.Page<OutstandingErasure>(
            items: <OutstandingErasure>[],
            pageNumber: 1,
            pageSize: 20,
            totalItems: 0,
            totalPages: 1,
          ),
        ),
      );
      await store.write(
        AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
      );
      final container = await pumpApp(
        tester,
        overrides: <Override>[
          erasureRequestRepositoryProvider.overrideWithValue(erasures),
        ],
      );
      await container
          .read(erasureRequestListControllerProvider.notifier)
          .setOverdueOnly(true);
      expect(
        container.read(erasureRequestListControllerProvider),
        isA<ErasureRequestListLoaded>(),
      );

      // When
      await container.read(sessionControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();

      // Then
      final state = container.read(erasureRequestListControllerProvider);
      expect(state, isA<ErasureRequestListLoading>());
      expect(state.query.overdueOnly, isFalse);
    },
  );

  testWidgets('GivenTheApp_WhenStarted_ThenItsVersionIsShown', (tester) async {
    // Given no stored token

    // When
    await pumpApp(tester);

    // Then
    expect(find.text('Heimdall UI v$appVersion'), findsOneWidget);
  });

  testWidgets('GivenASession_WhenStarted_ThenHomeIsTheSelectedDestination', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );

    // When
    await pumpApp(tester);

    // Then
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 0);
    expect(find.text('Home'), findsWidgets);
  });
}

/// A token naming a User, which is the role the matrix hides the most from.
String _userJwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'id',
        'email': 'user@example.com',
        'role': 3,
      }),
    ),
  );

  return 'header.$payload.signature';
}

/// A store whose read does not complete until it is told to, so AF-07c's slow
/// read is a state a test can actually observe.
class _SlowTokenStore implements TokenStore {
  _SlowTokenStore(this._token);

  final AuthToken? _token;
  final Completer<AuthToken?> _pending = Completer<AuthToken?>();

  void finish() => _pending.complete(_token);

  @override
  Future<AuthToken?> read() => _pending.future;

  @override
  Future<void> write(AuthToken token) async {}

  @override
  Future<void> clear() async {}
}

/// A subject-rights-only token, as UI-30 restores one from storage.
String _restrictedJwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'id': 'person-1',
        'role': '3',
        'subjectRightsOnly': 'true',
      }),
    ),
  );

  return 'header.$payload.signature';
}
