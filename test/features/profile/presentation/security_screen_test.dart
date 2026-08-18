import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/two_factor.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/security_screen.dart';
import 'package:heimdall_ui/shared/widgets/qr_code.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'email': 'ada@example.com',
        'role': 3,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _off = TwoFactorStatus();
const _on = TwoFactorStatus(
  isActive: true,
  appEnabled: true,
  remainingRecoveryCodes: 8,
);

const _appSetup = TwoFactorSetup(
  method: TwoFactorMethod.app,
  otpAuthUri:
      'otpauth://totp/Heimdall:ada@example.com?secret=JBSWY3DPEHPK3PXP'
      '&issuer=Heimdall',
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockAuthRepository repository;
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
        authRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/profile/security',
      routes: <RouteBase>[
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('profile')),
        ),
        GoRoute(
          path: '/profile/security',
          builder: (context, state) => const SecurityScreen(),
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

  void answerStatusWith(Result<TwoFactorStatus> result) {
    when(() => repository.twoFactorStatus()).thenAnswer((_) async => result);
  }

  void answerEnableWith(Result<TwoFactorSetup> result) {
    when(
      () => repository.enableTwoFactor(any()),
    ).thenAnswer((_) async => result);
  }

  void answerConfirmWith(Result<List<String>> result) {
    when(
      () => repository.confirmTwoFactor(
        method: any(named: 'method'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerDisableWith(Result<void> result) {
    when(
      () => repository.disableTwoFactor(
        password: any(named: 'password'),
        code: any(named: 'code'),
        recoveryCode: any(named: 'recoveryCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerRegenerateWith(Result<List<String>> result) {
    when(
      () => repository.regenerateRecoveryCodes(
        code: any(named: 'code'),
        recoveryCode: any(named: 'recoveryCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUpAll(() => registerFallbackValue(TwoFactorMethod.app));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
    answerStatusWith(const Success<TwoFactorStatus>(_off));
    answerEnableWith(const Success<TwoFactorSetup>(_appSetup));
    answerConfirmWith(const Success<List<String>>(<String>['aaa', 'bbb']));
    answerDisableWith(const Success<void>(null));
    answerRegenerateWith(const Success<List<String>>(<String>['xxx', 'yyy']));
  });

  // Main flow, step 1 — the section states whether it is on.
  testWidgets('GivenItIsOff_WhenOpened_ThenItSaysSo', (tester) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Two-factor authentication is off'), findsOneWidget);
  });

  testWidgets('GivenItIsOn_WhenOpened_ThenItSaysSoAndNamesTheMethod', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));

    // When
    await pump(tester);

    // Then
    expect(find.text('Two-factor authentication is on'), findsOneWidget);
    expect(find.textContaining('authenticator app'), findsWidgets);
  });

  testWidgets('GivenItIsOn_WhenOpened_ThenRemainingCodesAreStated', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('8 unused'), findsOneWidget);
  });

  testWidgets('GivenItIsOff_WhenOpened_ThenBothMethodsAreOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Authenticator app'), findsOneWidget);
    expect(find.text('Emailed code'), findsOneWidget);
  });

  // Main flow, steps 2–4 — the app method shows a scannable code.
  testWidgets('GivenTheAppMethod_WhenStarted_ThenAScannableCodeIsShown', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(QrCodeView), findsOneWidget);
  });

  // FR-AU-18 and AF-09e — the secret is always selectable text beside it.
  testWidgets('GivenTheAppMethod_WhenStarted_ThenTheSecretIsSelectable', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.widgetWithText(SelectableText, 'JBSWY3DPEHPK3PXP'),
      findsOneWidget,
    );
  });

  // AF-09e — a code that cannot be drawn must not block the setup.
  testWidgets('GivenAnUndrawableUri_WhenStarted_ThenTheSecretStillShows', (
    tester,
  ) async {
    // Given
    answerEnableWith(
      Success<TwoFactorSetup>(
        TwoFactorSetup(
          method: TwoFactorMethod.app,
          // Too long to fit into any symbol, so nothing can be drawn.
          otpAuthUri: 'otpauth://totp/x?secret=${'A' * 10000}',
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(QrCodeView), findsNothing);
    expect(find.textContaining('could not be drawn'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('GivenTheEmailMethod_WhenStarted_ThenTheSentCodeIsMentioned', (
    tester,
  ) async {
    // Given
    answerEnableWith(
      const Success<TwoFactorSetup>(
        TwoFactorSetup(method: TwoFactorMethod.email, emailCodeSent: true),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Emailed code'));
    await tester.pumpAndSettle();

    // Then
    expect(find.textContaining('emailed you a code'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
  });

  testWidgets('GivenACode_WhenConfirmed_ThenTheRecoveryCodesAreShown', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Your recovery codes'), findsOneWidget);
    expect(find.textContaining('aaa'), findsWidgets);
  });

  // AF-09a — a rejected code keeps the setup alive.
  testWidgets('GivenAWrongCode_WhenConfirmed_ThenTheSetupIsStillOpen', (
    tester,
  ) async {
    // Given
    answerConfirmWith(
      const FailureResult<List<String>>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That code is not correct.'],
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('That code is not correct.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Confirm'), findsOneWidget);
  });

  testWidgets('GivenAnEmptyCode_WhenConfirmed_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.confirmTwoFactor(
        method: any(named: 'method'),
        code: any(named: 'code'),
      ),
    );
  });

  // AF-09b — leaving before confirming keeps it off.
  testWidgets('GivenAPendingSetup_WhenCancelled_ThenItStaysOff', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Two-factor authentication is off'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
  });

  // AF-09c — the codes are shown once, so leaving is stopped first.
  testWidgets('GivenIssuedCodes_WhenLeaving_ThenConfirmationIsAsked', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.byTooltip('Back to your profile'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Leave without your recovery codes?'), findsOneWidget);
  });

  testWidgets('GivenIssuedCodes_WhenStaying_ThenTheCodesAreStillShown', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to your profile'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Stay'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Your recovery codes'), findsOneWidget);
  });

  testWidgets('GivenIssuedCodes_WhenAcknowledged_ThenTheSectionSettles', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);
    await tester.tap(find.text('Generate new codes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Code from your second factor'),
      '123456',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(
      find.widgetWithText(FilledButton, 'I have saved my codes'),
    );
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Two-factor authentication is on'), findsOneWidget);
  });

  testWidgets('GivenRegeneratedCodes_WhenShown_ThenTheOldOnesAreSaidToStop', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);
    await tester.tap(find.text('Generate new codes'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextField, 'Code from your second factor'),
      '123456',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    // Then
    expect(find.textContaining('replace your previous codes'), findsOneWidget);
  });

  testWidgets('GivenAPassword_WhenDisabled_ThenItIsSent', (tester) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);
    await tester.tap(find.text('Turn off two-factor'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.disableTwoFactor(
        password: 'secret',
        code: null,
        recoveryCode: null,
      ),
    ).called(1);
  });

  // Nothing filled in is nothing to send.
  testWidgets('GivenNoCredential_WhenDisabling_ThenConfirmIsDisabled', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);

    // When
    await tester.tap(find.text('Turn off two-factor'));
    await tester.pumpAndSettle();

    // Then
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Turn off'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenTheDisableDialog_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);
    await tester.tap(find.text('Turn off two-factor'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.disableTwoFactor(
        password: any(named: 'password'),
        code: any(named: 'code'),
        recoveryCode: any(named: 'recoveryCode'),
      ),
    );
  });

  // AF-09d — the API rejected the credential, and the feature stays on.
  testWidgets('GivenARejectedCredential_WhenDisabled_ThenItStaysOn', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerDisableWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That password is not correct.'],
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Turn off two-factor'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('That password is not correct.'), findsOneWidget);
    expect(find.text('Two-factor authentication is on'), findsOneWidget);
  });

  // Regenerating takes a code or a recovery code, never a password.
  testWidgets('GivenTheRegenerateDialog_WhenOpened_ThenNoPasswordIsAsked', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);

    // When
    await tester.tap(find.text('Generate new codes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextField, 'Password'), findsNothing);
  });

  // A Google User may never configure this here.
  testWidgets('GivenAGoogleUser_WhenOpened_ThenTheReasonIsExplained', (
    tester,
  ) async {
    // Given
    answerStatusWith(
      const FailureResult<TwoFactorStatus>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for this account'), findsOneWidget);
  });

  testWidgets('GivenATransportFailure_WhenOpened_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    answerStatusWith(
      const FailureResult<TwoFactorStatus>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenNothingPending_WhenLeaving_ThenTheProfileOpens', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.byTooltip('Back to your profile'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('profile'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheSectionIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('Two-factor authentication is off'), findsOneWidget);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheSectionIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Two-factor authentication is off'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheSectionIsStillShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Two-factor authentication is off'), findsOneWidget);
  });
}
