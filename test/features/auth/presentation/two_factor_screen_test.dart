import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/two_factor_screen.dart';
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
  late ProviderContainer container;

  AuthToken tokenFor(String value) =>
      AuthToken(value: value, expiresAt: DateTime.utc(2030));

  /// Pumps the screen with a challenge already in progress, since that is the
  /// only state it is reachable in.
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    ThemeData? theme,
    List<String> methods = const <String>['Totp'],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(
        TwoFactorRequired(
          challengeToken: 'challenge',
          availableMethods: methods,
        ),
      ),
    );
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    // Settle the start-up read first, so it cannot land on the challenge.
    await controller.restore();
    await controller.signIn(email: 'a@b.c', password: 'secret');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const TwoFactorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Advances the clock without waiting for animations to end: once the
  /// challenge is over the screen shows a progress indicator, which never
  /// settles.
  Future<void> flush(WidgetTester tester) async {
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> enterAndVerify(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextFormField), code);
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await flush(tester);
  }

  void answerVerifyWith(Result<AuthToken> result, {bool recovery = false}) {
    when(
      () => repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: any(named: 'code'),
        isRecoveryCode: recovery,
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenChallengeScreen_WhenCodeSubmitted_ThenTheCodeIsVerified', (
    tester,
  ) async {
    // Given
    answerVerifyWith(Success<AuthToken>(tokenFor(_jwt)));
    await pump(tester);

    // When
    await enterAndVerify(tester, '123456');

    // Then
    verify(
      () => repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: '123456',
        isRecoveryCode: false,
      ),
    ).called(1);
  });

  testWidgets('GivenAcceptedCode_WhenSubmitted_ThenSessionIsAuthenticated', (
    tester,
  ) async {
    // Given
    answerVerifyWith(Success<AuthToken>(tokenFor(_jwt)));
    await pump(tester);

    // When
    await enterAndVerify(tester, '123456');

    // Then
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // AF-02a — wrong code.
  testWidgets('GivenWrongCode_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<AuthToken>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The code is incorrect.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await enterAndVerify(tester, '000000');

    // Then
    expect(find.text('The code is incorrect.'), findsOneWidget);
  });

  // AF-02a — the rejected code is worth nothing, and the challenge stands.
  testWidgets(
    'GivenWrongCode_WhenSubmitted_ThenTheFieldIsClearedAndChallengeKept',
    (tester) async {
      // Given
      answerVerifyWith(
        const FailureResult<AuthToken>(
          Failure(kind: FailureKind.validation, errors: <String>['Wrong.']),
        ),
      );
      await pump(tester);

      // When
      await enterAndVerify(tester, '000000');

      // Then
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
      expect(container.read(sessionControllerProvider), isA<Challenged>());
    },
  );

  // AF-02b — challenge expired or rejected.
  testWidgets('GivenExpiredChallenge_WhenSubmitted_ThenRestartIsExplained', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<AuthToken>(
        Failure(kind: FailureKind.unauthorized, errors: <String>['Expired.']),
      ),
    );
    await pump(tester);

    // When
    await enterAndVerify(tester, '123456');

    // Then
    expect(
      find.text('That sign-in attempt expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  // AF-02c — more than one method available.
  testWidgets('GivenSeveralMethods_WhenRendered_ThenTheChoiceIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, methods: const <String>['Totp', 'Email']);

    // Then
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
  });

  // AF-02c — a single method is not a choice, so nothing is offered.
  testWidgets('GivenOneMethod_WhenRendered_ThenNoChoiceIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.byType(SegmentedButton<String>), findsNothing);
  });

  // AF-02c — switching changes what the screen asks for, and is remembered.
  testWidgets('GivenSeveralMethods_WhenOneIsChosen_ThenThePromptFollowsIt', (
    tester,
  ) async {
    // Given
    await pump(tester, methods: const <String>['Totp', 'Email']);

    // When
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('Enter the code we sent to your email address.'),
      findsOneWidget,
    );
    expect(
      (container.read(sessionControllerProvider) as Challenged).methodInUse,
      'Email',
    );
  });

  // AF-02d — a recovery code answers the challenge just as well.
  testWidgets('GivenRecoveryCodeChosen_WhenSubmitted_ThenItIsSentAsOne', (
    tester,
  ) async {
    // Given
    answerVerifyWith(Success<AuthToken>(tokenFor(_jwt)), recovery: true);
    await pump(tester);
    await tester.tap(find.text('Use a recovery code instead'));
    await tester.pumpAndSettle();

    // When
    await enterAndVerify(tester, 'recovery-code');

    // Then
    verify(
      () => repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: 'recovery-code',
        isRecoveryCode: true,
      ),
    ).called(1);
  });

  // AF-02d — using one spends it, and the user is told so.
  testWidgets('GivenRecoveryCodeAccepted_WhenSubmitted_ThenTheUserIsReminded', (
    tester,
  ) async {
    // Given
    answerVerifyWith(Success<AuthToken>(tokenFor(_jwt)), recovery: true);
    await pump(tester);
    await tester.tap(find.text('Use a recovery code instead'));
    await tester.pumpAndSettle();

    // When
    await enterAndVerify(tester, 'recovery-code');

    // Then
    expect(
      find.textContaining('That recovery code has now been used.'),
      findsOneWidget,
    );
  });

  // AF-02e — abandoned challenge.
  testWidgets('GivenChallengeScreen_WhenLeft_ThenTheChallengeIsDiscarded', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Back to sign in'));
    await flush(tester);

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  testWidgets('GivenEmptyCode_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await enterAndVerify(tester, '');

    // Then
    verifyNever(
      () => repository.verifySecondFactor(
        challengeToken: any(named: 'challengeToken'),
        code: any(named: 'code'),
        isRecoveryCode: any(named: 'isRecoveryCode'),
      ),
    );
    expect(find.text('Enter your verification code.'), findsOneWidget);
  });

  testWidgets('GivenTransportFailure_WhenSubmitted_ThenRetryBannerIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<AuthToken>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await enterAndVerify(tester, '123456');

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  // The transport rejected nothing, so the code survives to be sent again.
  testWidgets('GivenTransportFailure_WhenSubmitted_ThenTheCodeIsKept', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<AuthToken>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await enterAndVerify(tester, '123456');

    // Then
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '123456',
    );
  });

  testWidgets('GivenCompactWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify'), findsOneWidget);
  });

  testWidgets('GivenMediumWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(800, 900));

    // Then
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify'), findsOneWidget);
  });

  testWidgets('GivenExpandedWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify'), findsOneWidget);
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheFormIsShown', (tester) async {
    // Given / When
    await pump(
      tester,
      theme: buildDarkTheme(),
      methods: const <String>['Totp', 'Email'],
    );

    // Then
    expect(find.text('Two-step verification'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
