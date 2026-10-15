import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/scope/scope_source.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/two_factor_screen.dart';
import 'package:heimdall_ui/shared/widgets/failure_banner.dart';
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

    when(
      () => repository.login(
        email: 'a@b.c',
        password: 'secret',
        scopeId: any(named: 'scopeId'),
      ),
    ).thenAnswer(
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
        scopeSourceProvider.overrideWithValue(const FixedScopeSource(null)),
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

  void answerResendWith(Result<void> result) {
    when(() => repository.resendSecondFactorCode(challengeToken: 'challenge'))
        .thenAnswer((_) async => result);
  }

  Finder sendButton() => find.textContaining('Send a new code');

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

  testWidgets('GivenAnEmailChallenge_WhenRendered_ThenResendIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, methods: const <String>['Email']);

    // Then
    expect(sendButton(), findsOneWidget);
  });

  // AF-02f
  testWidgets('GivenAnAppChallenge_WhenRendered_ThenNoResendIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, methods: const <String>['Totp']);

    // Then
    expect(sendButton(), findsNothing);
  });

  testWidgets('GivenARecoveryCode_WhenChosen_ThenNoResendIsOffered', (
    tester,
  ) async {
    // Given
    await pump(tester, methods: const <String>['Email']);

    // When
    await tester.tap(find.text('Use a recovery code instead'));
    await tester.pumpAndSettle();

    // Then
    expect(sendButton(), findsNothing);
  });

  testWidgets('GivenAnEmailChallenge_WhenResent_ThenTheOutcomeIsHedged', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);

    // When
    await tester.tap(sendButton());
    await tester.pump();

    // Then
    verify(() => repository.resendSecondFactorCode(challengeToken: 'challenge'))
        .called(1);
    expect(
      find.text(
        'If your sign-in is still open, a new code is on its way. Codes '
        'sent before it no longer work.',
      ),
      findsOneWidget,
    );

    await tester.pump(resendCooldown);
  });

  testWidgets('GivenAResend_WhenWithinTheCooldown_ThenItWaits', (tester) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    await tester.tap(sendButton());
    await tester.pump();

    // When
    await tester.tap(sendButton());
    await tester.pump(const Duration(seconds: 10));

    // Then
    verify(() => repository.resendSecondFactorCode(challengeToken: 'challenge'))
        .called(1);
    expect(find.text('Send a new code (20s)'), findsOneWidget);

    await tester.pump(resendCooldown);
  });

  testWidgets('GivenTheCooldown_WhenItEnds_ThenResendIsOfferedAgain', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    await tester.tap(sendButton());
    await tester.pump();

    // When
    await tester.pump(const Duration(seconds: 30));

    // Then
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Send a new code'),
    );
    expect(button.onPressed, isNotNull);
  });

  // AF-02g
  testWidgets('GivenThreeResends_WhenRendered_ThenStartOverReplacesIt', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);

    // When
    for (var send = 0; send < 3; send++) {
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
    }

    // Then
    expect(sendButton(), findsNothing);
    expect(find.text('For another code, sign in again.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Start over'), findsOneWidget);
  });

  testWidgets('GivenStartOver_WhenTapped_ThenTheChallengeIsDiscarded', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    for (var send = 0; send < 3; send++) {
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
    }

    // When
    await tester.tap(find.widgetWithText(OutlinedButton, 'Start over'));
    await flush(tester);

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  // AF-02h
  testWidgets('GivenAFailedResend_WhenTapped_ThenItIsNotCounted', (
    tester,
  ) async {
    // Given
    answerResendWith(
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester, methods: const <String>['Email']);

    // When
    await tester.tap(sendButton());
    await tester.pump();

    // Then
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Send a new code'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.byType(ErrorBanner), findsOneWidget);
  });

  testWidgets('GivenFailedResends_WhenSendsSucceedAfter_ThenOnlyTheyCount', (
    tester,
  ) async {
    // Given
    final results = <Result<void>>[
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
      const Success<void>(null),
      const Success<void>(null),
      const Success<void>(null),
    ];
    when(() => repository.resendSecondFactorCode(challengeToken: 'challenge'))
        .thenAnswer((_) async => results.removeAt(0));
    await pump(tester, methods: const <String>['Email']);

    // When
    for (var send = 0; send < 4; send++) {
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
    }

    // Then: two failures and two successes leave one send in hand.
    expect(sendButton(), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Start over'), findsNothing);

    // When
    await tester.tap(sendButton());
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    // Then
    expect(sendButton(), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Start over'), findsOneWidget);
  });

  testWidgets('GivenASentCode_WhenALaterSendFails_ThenTheNoteIsGone', (
    tester,
  ) async {
    // Given
    final results = <Result<void>>[
      const Success<void>(null),
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    ];
    when(() => repository.resendSecondFactorCode(challengeToken: 'challenge'))
        .thenAnswer((_) async => results.removeAt(0));
    await pump(tester, methods: const <String>['Email']);
    await tester.tap(sendButton());
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    // When
    await tester.tap(sendButton());
    await tester.pump();

    // Then
    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(find.textContaining('a new code is on its way'), findsNothing);
  });

  testWidgets('GivenSendsOnEmail_WhenTheMethodIsSwitched_ThenTheyStillCount', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Totp', 'Email']);
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.tap(sendButton());
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    // When
    await tester.tap(find.text('Authenticator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    for (var send = 0; send < 2; send++) {
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
    }

    // Then
    expect(sendButton(), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Start over'), findsOneWidget);
  });

  testWidgets('GivenATypedCode_WhenResent_ThenItIsKept', (tester) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    await tester.enterText(find.byType(TextFormField), '12');

    // When
    await tester.tap(sendButton());
    await tester.pump();

    // Then
    expect(find.text('12'), findsOneWidget);

    await tester.pump(resendCooldown);
  });

  testWidgets('GivenCompactWidth_WhenEmailRendered_ThenResendIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, methods: const <String>['Email']);

    // Then
    expect(sendButton(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenMediumWidth_WhenEmailRendered_ThenResendIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(
      tester,
      size: const Size(800, 900),
      methods: const <String>['Email'],
    );

    // Then
    expect(sendButton(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenExpandedWidth_WhenEmailRendered_ThenResendIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(
      tester,
      size: const Size(1400, 900),
      methods: const <String>['Email'],
    );

    // Then
    expect(sendButton(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenDarkTheme_WhenEmailRendered_ThenResendIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(
      tester,
      theme: buildDarkTheme(),
      methods: const <String>['Email'],
    );

    // Then
    expect(sendButton(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
