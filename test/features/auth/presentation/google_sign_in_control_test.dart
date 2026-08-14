import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/google_sign_in_gateway.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/google_sign_in_control.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/shared/widgets/failure_banner.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Google's half, faked: what it would have returned, without its SDK.
class _FakeGoogleSignInGateway implements GoogleSignInGateway {
  _FakeGoogleSignInGateway({
    this.availability = GoogleSignInAvailability.interactive,
    this.attempt = const GoogleIdTokenObtained('google-id-token'),
  });

  @override
  final GoogleSignInAvailability availability;

  final GoogleSignInAttempt attempt;

  final StreamController<GoogleIdTokenObtained> tokens =
      StreamController<GoogleIdTokenObtained>.broadcast();

  int initializations = 0;
  int signOuts = 0;

  @override
  Future<void> initialize() async => initializations++;

  @override
  Stream<GoogleIdTokenObtained> get idTokens => tokens.stream;

  @override
  Future<GoogleSignInAttempt> obtainIdToken() async => attempt;

  @override
  Future<void> signOut() async => signOuts++;
}

/// A token naming a User, which is all the control's outcomes need.
const String _jwt =
    'header.'
    'eyJzdWIiOiJpZCIsImVtYWlsIjoiYUBiLmMiLCJyb2xlIjozfQ.'
    'signature';

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;
  late _FakeGoogleSignInGateway gateway;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    String? scopeId = 'scope-public-id',
    ThemeData? theme,
  }) async {
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
        googleSignInGatewayProvider.overrideWithValue(gateway),
        scopeSourceProvider.overrideWithValue(FixedScopeSource(scopeId)),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(gateway.tokens.close);
    // Settle the start-up read so it cannot land mid-exchange.
    await container.read(sessionControllerProvider.notifier).restore();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const Scaffold(body: GoogleSignInControl(enabled: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void answerExchangeWith(Result<AuthToken> result) {
    when(
      () => repository.signInWithGoogle(
        idToken: any(named: 'idToken'),
        scopeId: any(named: 'scopeId'),
      ),
    ).thenAnswer((_) async => result);
  }

  AuthToken googleToken() =>
      AuthToken(value: _jwt, expiresAt: DateTime.utc(2030), viaGoogle: true);

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
    gateway = _FakeGoogleSignInGateway();
  });

  testWidgets('GivenAGoogleIdToken_WhenActivated_ThenItIsExchanged', (
    tester,
  ) async {
    // Given
    answerExchangeWith(Success<AuthToken>(googleToken()));
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.signInWithGoogle(
        idToken: 'google-id-token',
        scopeId: 'scope-public-id',
      ),
    ).called(1);
  });

  testWidgets(
    'GivenAcceptedExchange_WhenActivated_ThenSessionIsAuthenticated',
    (tester) async {
      // Given
      answerExchangeWith(Success<AuthToken>(googleToken()));
      await pump(tester);

      // When
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Then
      expect(container.read(sessionControllerProvider), isA<Authenticated>());
    },
  );

  // The scope belongs to the calling application; when it named none, the API
  // is asked without one rather than being sent something invented.
  testWidgets('GivenNoScopeFromTheCaller_WhenActivated_ThenNoScopeIsSent', (
    tester,
  ) async {
    // Given
    answerExchangeWith(Success<AuthToken>(googleToken()));
    await pump(tester, scopeId: null);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.signInWithGoogle(
        idToken: 'google-id-token',
        scopeId: null,
      ),
    ).called(1);
  });

  // AF-06b — the scope has Google Sign-In switched off.
  testWidgets('GivenDisabledScope_WhenActivated_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerExchangeWith(
      const FailureResult<AuthToken>(
        Failure(
          kind: FailureKind.forbidden,
          errors: <String>['Google Sign-In is not enabled for this scope.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('Google Sign-In is not enabled for this scope.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenDisabledScope_WhenActivated_ThenTheControlIsStillOffered', (
    tester,
  ) async {
    // Given
    answerExchangeWith(
      const FailureResult<AuthToken>(
        Failure(kind: FailureKind.forbidden, errors: <String>['No.']),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  // AF-06d — Heimdall refuses the ID token, and the pending Google session is
  // dropped so the next attempt starts from the account chooser.
  testWidgets('GivenRejectedIdToken_WhenActivated_ThenGoogleIsSignedOut', (
    tester,
  ) async {
    // Given
    answerExchangeWith(
      const FailureResult<AuthToken>(
        Failure(
          kind: FailureKind.unauthorized,
          errors: <String>['That Google account could not be signed in.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    expect(gateway.signOuts, 1);
  });

  testWidgets('GivenRejectedIdToken_WhenActivated_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerExchangeWith(
      const FailureResult<AuthToken>(
        Failure(
          kind: FailureKind.unauthorized,
          errors: <String>['That Google account could not be signed in.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('That Google account could not be signed in.'),
      findsOneWidget,
    );
  });

  // AF-06c — the user backs out of Google's flow.
  testWidgets('GivenACancelledFlow_WhenActivated_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    gateway = _FakeGoogleSignInGateway(attempt: const GoogleSignInCancelled());
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.signInWithGoogle(
        idToken: any(named: 'idToken'),
        scopeId: any(named: 'scopeId'),
      ),
    );
  });

  testWidgets('GivenACancelledFlow_WhenActivated_ThenTheScreenIsUnchanged', (
    tester,
  ) async {
    // Given
    gateway = _FakeGoogleSignInGateway(attempt: const GoogleSignInCancelled());
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(ErrorBanner), findsNothing);
  });

  testWidgets('GivenGoogleUnavailable_WhenActivated_ThenTheReasonIsShown', (
    tester,
  ) async {
    // Given
    gateway = _FakeGoogleSignInGateway(
      attempt: const GoogleSignInUnavailable('Google is not configured.'),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Google is not configured.'), findsOneWidget);
  });

  // Where Google renders its own control, the ID token arrives on a stream
  // rather than as the result of a call.
  testWidgets('GivenAPlatformControl_WhenTokenArrives_ThenItIsExchanged', (
    tester,
  ) async {
    // Given
    gateway = _FakeGoogleSignInGateway(
      availability: GoogleSignInAvailability.platformControl,
    );
    answerExchangeWith(Success<AuthToken>(googleToken()));
    await pump(tester);

    // When
    gateway.tokens.add(const GoogleIdTokenObtained('google-id-token'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.signInWithGoogle(
        idToken: 'google-id-token',
        scopeId: 'scope-public-id',
      ),
    ).called(1);
  });

  testWidgets('GivenAPlatformControl_WhenRendered_ThenTheSdkIsInitialized', (
    tester,
  ) async {
    // Given
    gateway = _FakeGoogleSignInGateway(
      availability: GoogleSignInAvailability.platformControl,
    );

    // When
    await pump(tester);

    // Then
    expect(gateway.initializations, 1);
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheControlIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
