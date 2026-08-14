import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/heimdall_app.dart';
import 'package:heimdall_ui/app/router.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

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
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        // The sign-in screen asks the configuration whether to offer the
        // Google control, so the whole app needs one to render.
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:5000'),
        ),
        tokenStoreProvider.overrideWithValue(store),
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
    expect(find.text('Signed in as admin@example.com'), findsOneWidget);
    expect(find.text('System Admin'), findsOneWidget);
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
    expect(find.text('Signed in as admin@example.com'), findsOneWidget);
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
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:5000'),
        ),
        tokenStoreProvider.overrideWithValue(slow),
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
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:5000'),
        ),
        tokenStoreProvider.overrideWithValue(slow),
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
    expect(find.text('Signed in as admin@example.com'), findsOneWidget);
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
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:5000'),
        ),
        tokenStoreProvider.overrideWithValue(store),
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
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:5000'),
        ),
        tokenStoreProvider.overrideWithValue(store),
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
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://localhost:5000'),
        ),
        tokenStoreProvider.overrideWithValue(store),
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
