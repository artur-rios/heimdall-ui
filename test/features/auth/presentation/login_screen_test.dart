import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/login_screen.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// A token whose payload names a User, which is all the screen's flows need.
const String _jwt =
    'header.'
    'eyJzdWIiOiJpZCIsImVtYWlsIjoiYUBiLmMiLCJyb2xlIjozfQ.'
    'signature';

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;

  const withoutGoogle = AppConfig(apiBaseUrl: 'http://localhost:5000');
  const withGoogle = AppConfig(
    apiBaseUrl: 'http://localhost:5000',
    googleClientId: 'client-id.apps.googleusercontent.com',
  );

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    ThemeData? theme,
    AppConfig config = withoutGoogle,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(config),
          authRepositoryProvider.overrideWithValue(repository),
          tokenStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String email = 'a@b.c',
    String password = 'secret',
  }) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.enterText(find.byType(TextFormField).last, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
  });

  testWidgets(
    'GivenLoginScreen_WhenSubmittedWithValidInput_ThenControllerIsCalled',
    (tester) async {
      // Given
      when(
        () => repository.login(email: 'a@b.c', password: 'secret'),
      ).thenAnswer(
        (_) async => Success<LoginOutcome>(
          LoggedIn(AuthToken(value: _jwt, expiresAt: DateTime.utc(2030))),
        ),
      );
      await pump(tester);

      // When
      await fillAndSubmit(tester);

      // Then
      verify(
        () => repository.login(email: 'a@b.c', password: 'secret'),
      ).called(1);
    },
  );

  // AF-01a — invalid credentials.
  testWidgets('GivenRejectedLogin_WhenRendered_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => const FailureResult<LoginOutcome>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Invalid email or password.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await fillAndSubmit(tester);

    // Then
    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  // AF-01a — the address survives a rejection, the secret does not.
  testWidgets('GivenRejectedLogin_WhenRendered_ThenEmailKeptAndPasswordClear', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => const FailureResult<LoginOutcome>(
        Failure(kind: FailureKind.validation, errors: <String>['Rejected.']),
      ),
    );
    await pump(tester);

    // When
    await fillAndSubmit(tester);

    // Then
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.controller?.text, 'a@b.c');
    expect(fields.last.controller?.text, isEmpty);
  });

  // AF-01b — client-side validation.
  testWidgets('GivenEmptyPassword_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await fillAndSubmit(tester, password: '');

    // Then
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  // AF-01b — a malformed address is refused before a request is made.
  testWidgets('GivenMalformedEmail_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await fillAndSubmit(tester, email: 'not-an-address');

    // Then
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  // AF-01d — API unreachable.
  testWidgets('GivenTransportFailure_WhenSubmitted_ThenRetryBannerIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => const FailureResult<LoginOutcome>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await fillAndSubmit(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  // AF-01d — the retry sends the same submission again.
  testWidgets('GivenRetryBanner_WhenRetryTapped_ThenLoginIsAttemptedAgain', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => const FailureResult<LoginOutcome>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);
    await fillAndSubmit(tester);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.login(email: 'a@b.c', password: 'secret'),
    ).called(2);
  });

  // AF-01e — the Google control, offered only when the build configures it.
  testWidgets('GivenGoogleClientId_WhenRendered_ThenGoogleControlIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, config: withGoogle);

    // Then
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  // AF-06a — no client id, no control at all.
  testWidgets('GivenNoGoogleClientId_WhenRendered_ThenGoogleControlIsHidden', (
    tester,
  ) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('GivenCompactWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('GivenMediumWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(800, 900));

    // Then
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('GivenExpandedWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheFormIsShown', (tester) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme(), config: withGoogle);

    // Then
    expect(find.text('Heimdall'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
