import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/secrets/screen_security.dart';
import 'package:heimdall_ui/core/secrets/secret_clipboard.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/domain/two_factor.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/profile/presentation/security_screen.dart';
import 'package:heimdall_ui/shared/widgets/qr_code.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/secret_fakes.dart';

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
  late RecordingSecretClipboard secrets;
  late RecordingScreenSecurity security;
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
        secretClipboardProvider.overrideWithValue(secrets),
        screenSecurityProvider.overrideWithValue(security),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    // The application's guard sends a signed-out person to sign-in; this
    // stands in for it, so a sign-out lands somewhere that settles.
    final sessionChanges = ValueNotifier<int>(0);
    addTearDown(sessionChanges.dispose);
    container.listen(
      sessionControllerProvider,
      (_, _) => sessionChanges.value++,
    );

    // Built under a provider, as the application's is, so the security
    // route's onExit has the Ref it reads the codes and the session through.
    final routerProvider = Provider<GoRouter>(
      (ref) => GoRouter(
        initialLocation: '/profile/security',
        refreshListenable: sessionChanges,
        redirect: (context, state) =>
            ref.read(sessionControllerProvider) is Unauthenticated
            ? '/login'
            : null,
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('sign-in')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: Text('profile')),
          ),
          GoRoute(
            path: '/profile/security',
            builder: (context, state) => const SecurityScreen(),
            onExit: (context, state) =>
                confirmLeaveWithRecoveryCodes(context, ref),
          ),
        ],
      ),
    );
    router = container.read(routerProvider);
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
      () => repository.enableTwoFactor(
        any(),
        currentPassword: any(named: 'currentPassword'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Chooses [method] and confirms it with the current password, which is
  /// what starting a setup takes (FR-AU-17).
  Future<void> startSetup(
    WidgetTester tester,
    String method, {
    String password = 'secret',
  }) async {
    await tester.tap(find.text(method));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Current password'),
      password,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
  }

  SessionState session() => container.read(sessionControllerProvider);

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
    secrets = RecordingSecretClipboard();
    security = RecordingScreenSecurity();
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
    await startSetup(tester, 'Authenticator app');

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
    await startSetup(tester, 'Authenticator app');

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
    await startSetup(tester, 'Authenticator app');

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
    await startSetup(tester, 'Emailed code');

    // Then
    expect(find.textContaining('emailed you a code'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
  });

  testWidgets('GivenACode_WhenConfirmed_ThenTheRecoveryCodesAreShown', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await startSetup(tester, 'Authenticator app');

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
    await startSetup(tester, 'Authenticator app');

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
    await startSetup(tester, 'Authenticator app');

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
    await startSetup(tester, 'Authenticator app');

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
    await startSetup(tester, 'Authenticator app');
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
    await startSetup(tester, 'Authenticator app');
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

  // FR-AU-28 — new codes revoke the token, so once they are acknowledged the
  // person signs in again.
  testWidgets('GivenRegeneratedCodes_WhenAcknowledged_ThenTheSessionEnds', (
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
    expect(session(), isA<Authenticated>());

    // When
    await tester.tap(
      find.widgetWithText(FilledButton, 'I have saved my codes'),
    );
    await tester.pumpAndSettle();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    expect(find.text('sign-in'), findsOneWidget);
  });

  // FR-AU-28 — confirming revokes the token too: the codes are shown first,
  // and acknowledging them signs the person out.
  testWidgets('GivenConfirmedCodes_WhenAcknowledged_ThenTheSessionEnds', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await startSetup(tester, 'Authenticator app');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Your recovery codes'), findsOneWidget);
    expect(session(), isA<Authenticated>());

    // When
    await tester.tap(
      find.widgetWithText(FilledButton, 'I have saved my codes'),
    );
    await tester.pumpAndSettle();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    expect(find.text('sign-in'), findsOneWidget);
  });

  // Leaving without them is leaving all the same, under a revoked token.
  testWidgets('GivenIssuedCodes_WhenLeftAnyway_ThenTheSessionEnds', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await startSetup(tester, 'Authenticator app');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to your profile'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Leave anyway'));
    await tester.pumpAndSettle();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    expect(find.text('sign-in'), findsOneWidget);
  });

  // FR-AU-17 — choosing a method asks for the current password first.
  testWidgets('GivenAMethod_WhenChosen_ThenThePasswordIsAsked', (tester) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.text('Authenticator app'));
    await tester.pumpAndSettle();

    // Then
    expect(find.widgetWithText(TextField, 'Current password'), findsOneWidget);
    verifyNever(
      () => repository.enableTwoFactor(
        any(),
        currentPassword: any(named: 'currentPassword'),
      ),
    );
  });

  testWidgets('GivenNoPassword_WhenChoosingAMethod_ThenContinueIsDisabled', (
    tester,
  ) async {
    // Given
    await pump(tester);

    // When
    await tester.tap(find.text('Emailed code'));
    await tester.pumpAndSettle();

    // Then
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('GivenAPassword_WhenTheSetupStarts_ThenItIsSent', (tester) async {
    // Given
    await pump(tester);

    // When
    await startSetup(tester, 'Emailed code', password: 'pw');

    // Then
    verify(
      () => repository.enableTwoFactor(
        TwoFactorMethod.email,
        currentPassword: 'pw',
      ),
    ).called(1);
  });

  // AF-09f — a wrong password is shown on the screen, the feature stays off,
  // and the person stays signed in to correct it.
  // AF-09f — a wrong password keeps the dialog open with the refusal in it,
  // so the person retypes it there; the feature stays off and the session
  // stays.
  testWidgets('GivenAWrongPassword_WhenTheSetupStarts_ThenTheDialogStays', (
    tester,
  ) async {
    // Given
    answerEnableWith(
      const FailureResult<TwoFactorSetup>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The current password is incorrect.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await startSetup(tester, 'Authenticator app', password: 'wrong');

    // Then
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('The current password is incorrect.'),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Current password'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
    expect(session(), isA<Authenticated>());
  });

  // AF-09h — the email method spends the account-email budget, whose 429
  // carries Retry-After. The dialog says so and holds Continue back that long.
  testWidgets('GivenAMailCooldown_WhenTheEmailSetupStarts_ThenContinueWaits', (
    tester,
  ) async {
    // Given
    const cooldown =
        'An email of this kind was sent to you recently. Try again in a few '
        'minutes.';
    answerEnableWith(
      const FailureResult<TwoFactorSetup>(
        Failure(
          kind: FailureKind.rateLimited,
          errors: <String>[cooldown],
          retryAfter: Duration(seconds: 90),
        ),
      ),
    );
    await pump(tester);

    // When
    await startSetup(tester, 'Emailed code');

    // Then
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text(cooldown)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Try again in 2 minutes.'),
      ),
      findsOneWidget,
    );
    final proceed = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(proceed).onPressed, isNull);

    await tester.pump(const Duration(seconds: 90));
    expect(tester.widget<FilledButton>(proceed).onPressed, isNotNull);
    expect(session(), isA<Authenticated>());
  });

  testWidgets('GivenAHugeRetryAfter_WhenTheEmailSetupStarts_ThenItWaitsADay', (
    tester,
  ) async {
    // Given
    answerEnableWith(
      const FailureResult<TwoFactorSetup>(
        Failure(
          kind: FailureKind.rateLimited,
          errors: <String>['Too many requests.'],
          retryAfter: Duration(days: 365),
        ),
      ),
    );
    await pump(tester);

    // When
    await startSetup(tester, 'Emailed code');

    // Then
    final proceed = find.widgetWithText(FilledButton, 'Continue');
    await tester.pump(const Duration(hours: 23, minutes: 59));
    expect(tester.widget<FilledButton>(proceed).onPressed, isNull);
    await tester.pump(const Duration(minutes: 1));
    expect(tester.widget<FilledButton>(proceed).onPressed, isNotNull);
  });

  testWidgets('GivenARefusedPassword_WhenRetyped_ThenTheSetupStarts', (
    tester,
  ) async {
    // Given
    when(() => repository.enableTwoFactor(any(), currentPassword: 'wrong'))
        .thenAnswer(
          (_) async => const FailureResult<TwoFactorSetup>(
            Failure(
              kind: FailureKind.validation,
              errors: <String>['The current password is incorrect.'],
            ),
          ),
        );
    when(() => repository.enableTwoFactor(any(), currentPassword: 'secret'))
        .thenAnswer((_) async => const Success<TwoFactorSetup>(_appSetup));
    await pump(tester);
    await startSetup(tester, 'Authenticator app', password: 'wrong');

    // When
    await tester.enterText(
      find.widgetWithText(TextField, 'Current password'),
      'secret',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(QrCodeView), findsOneWidget);
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

  testWidgets('GivenTurnOff_WhenAsked_ThenItIsDestructive', (tester) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);

    // When
    await tester.tap(find.text('Turn off two-factor'));
    await tester.pumpAndSettle();

    // Then Cancel takes the focus and confirming looks destructive
    final scheme = Theme.of(tester.element(find.byType(AlertDialog)))
        .colorScheme;
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .autofocus,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Turn off'))
          .style!
          .backgroundColor!
          .resolve(<WidgetState>{}),
      scheme.error,
    );
  });

  testWidgets('GivenGenerateNewCodes_WhenAsked_ThenItIsDestructive', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);

    // When
    await tester.tap(find.text('Generate new codes'));
    await tester.pumpAndSettle();

    // Then Cancel takes the focus and confirming looks destructive
    final scheme = Theme.of(tester.element(find.byType(AlertDialog)))
        .colorScheme;
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .autofocus,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Generate'))
          .style!
          .backgroundColor!
          .resolve(<WidgetState>{}),
      scheme.error,
    );
  });

  // UC-39 — the API refuses to disable without the password *and* a second
  // factor, so both travel together.
  testWidgets('GivenAPasswordAndACode_WhenDisabled_ThenBothAreSent', (
    tester,
  ) async {
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
    await tester.enterText(
      find.widgetWithText(TextField, 'Code from your second factor'),
      '123456',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.disableTwoFactor(
        password: 'secret',
        code: '123456',
        recoveryCode: null,
      ),
    ).called(1);
  });

  testWidgets('GivenAPasswordAndARecoveryCode_WhenDisabled_ThenBothAreSent', (
    tester,
  ) async {
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
    await tester.enterText(
      find.widgetWithText(TextField, 'Recovery code'),
      'abcd-efgh',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.disableTwoFactor(
        password: 'secret',
        code: null,
        recoveryCode: 'abcd-efgh',
      ),
    ).called(1);
  });

  // Either half alone is a request the API always refuses.
  for (final (field, value) in <(String, String)>[
    ('Password', 'secret'),
    ('Code from your second factor', '123456'),
  ]) {
    testWidgets('GivenOneHalf_WhenDisabling_ThenConfirmIsDisabled: $field', (
      tester,
    ) async {
      // Given
      answerStatusWith(const Success<TwoFactorStatus>(_on));
      await pump(tester);
      await tester.tap(find.text('Turn off two-factor'));
      await tester.pumpAndSettle();

      // When
      await tester.enterText(find.widgetWithText(TextField, field), value);
      await tester.pumpAndSettle();

      // Then
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Turn off'))
            .onPressed,
        isNull,
      );
    });
  }

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
    await tester.enterText(
      find.widgetWithText(TextField, 'Code from your second factor'),
      '123456',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('That password is not correct.'), findsOneWidget);
    expect(find.text('Two-factor authentication is on'), findsOneWidget);
  });

  // FR-AU-28 — turning it off revokes the token, so the person signs in
  // again straight away.
  testWidgets('GivenACredential_WhenDisabled_ThenTheSessionEnds', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);
    await tester.tap(find.text('Turn off two-factor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Code from your second factor'),
      '123456',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    expect(find.text('sign-in'), findsOneWidget);
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

  // FR-2F-20 on the API — recovery codes are sixteen characters now, and the
  // dialogs take one whole, as typed.
  for (final (button, confirm) in <(String, String)>[
    ('Generate new codes', 'Generate'),
    ('Turn off two-factor', 'Turn off'),
  ]) {
    testWidgets('GivenANewRecoveryCode_WhenConfirmed_ThenItIsSentWhole: '
        '$button', (tester) async {
      // Given
      answerStatusWith(const Success<TwoFactorStatus>(_on));
      await pump(tester);
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();

      // When
      if (button == 'Turn off two-factor') {
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'secret',
        );
      }
      await tester.enterText(
        find.widgetWithText(TextField, 'Recovery code'),
        'abcd efgh-jkmn-pqrs',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, confirm));
      await tester.pumpAndSettle();

      // Then
      if (button == 'Turn off two-factor') {
        verify(
          () => repository.disableTwoFactor(
            password: 'secret',
            recoveryCode: 'abcd efgh-jkmn-pqrs',
          ),
        ).called(1);
      } else {
        verify(
          () => repository.regenerateRecoveryCodes(
            recoveryCode: 'abcd efgh-jkmn-pqrs',
          ),
        ).called(1);
      }
    });
  }

  testWidgets('GivenTheCredentialDialog_WhenShown_ThenNothingRewritesTheCode', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    await pump(tester);

    // When
    await tester.tap(find.text('Generate new codes'));
    await tester.pumpAndSettle();

    // Then
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Recovery code'),
    );
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.textCapitalization, TextCapitalization.characters);
  });

  testWidgets('GivenNewStyleCodes_WhenShown_ThenEachIsShownWhole', (
    tester,
  ) async {
    // Given
    const codes = <String>[
      'ABCD-EFGH-JKMN-PQRS',
      '0123-4567-89AB-CDEF',
      'WXYZ-TVSR-QPNM-KJHG',
    ];
    answerStatusWith(const Success<TwoFactorStatus>(_on));
    answerRegenerateWith(const Success<List<String>>(codes));
    await pump(tester, size: _compact);
    await tester.tap(find.text('Generate new codes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Code from your second factor'),
      '123456',
    );
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text(codes.join('\n')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The API keeps no flag for codes issued before they grew, so the hint is
  // for the person to recognise their own.
  testWidgets('GivenItIsOn_WhenOpened_ThenShortCodesAreSuggestedForRenewal', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_on));

    // When
    await pump(tester);

    // Then
    expect(
      find.text(
        'Codes in the shorter XXXX-XXXX form still work, but new ones are '
        'stronger: generate a new set to replace them.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenItIsOff_WhenOpened_ThenNoOlderCodesHintIsShown', (
    tester,
  ) async {
    // Given
    answerStatusWith(const Success<TwoFactorStatus>(_off));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('XXXX-XXXX form'), findsNothing);
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

  // AF-09c — the navigation is a way off the screen too, and must not throw
  // the codes away without asking.
  testWidgets('GivenIssuedCodes_WhenADestinationIsTapped_ThenItAsksFirst', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await startSetup(tester, 'Authenticator app');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Stay'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Your recovery codes'), findsOneWidget);
  });

  /// Confirms the app setup and leaves the recovery codes on screen.
  Future<void> issueCodes(WidgetTester tester) async {
    await pump(tester);
    await startSetup(tester, 'Authenticator app');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Your recovery codes'), findsOneWidget);
  }

  // The setup key and the recovery codes are secrets: the window is kept out of
  // screenshots while they show, and a copy of them does not linger.
  testWidgets(
    'GivenTheAppSetup_WhenShownAndLeft_ThenTheWindowIsSecuredMeanwhile',
    (tester) async {
      // Given
      await pump(tester);
      expect(security.held, 0);

      // When
      await startSetup(tester, 'Authenticator app');

      // Then
      expect(security.held, 1);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(security.held, 0);
    },
  );

  testWidgets(
    'GivenTheSetupKey_WhenCopied_ThenItGoesThroughTheSecretClipboard',
    (tester) async {
      // Given
      await pump(tester);
      await startSetup(tester, 'Authenticator app');

      // When
      await tester.tap(find.byTooltip('Copy setup key'));
      await tester.pumpAndSettle();

      // Then
      expect(secrets.copied, <String>['JBSWY3DPEHPK3PXP']);
    },
  );

  testWidgets('GivenRecoveryCodes_WhenShown_ThenTheWindowIsSecured', (
    tester,
  ) async {
    // When
    await issueCodes(tester);

    // Then
    expect(security.held, 1);
  });

  testWidgets(
    'GivenRecoveryCodes_WhenCopied_ThenTheyGoThroughTheSecretClipboard',
    (tester) async {
      // Given
      await issueCodes(tester);

      // When
      await tester.tap(find.text('Copy codes'));
      await tester.pumpAndSettle();

      // Then
      expect(secrets.copied, <String>['aaa\nbbb']);
    },
  );

  // AF-09c — on the web a browser Back, Forward or typed address is a route
  // change that PopScope and the shell never see, so the route itself asks.
  testWidgets('GivenIssuedCodes_WhenTheRouteIsLeft_ThenItAsks', (tester) async {
    // Given
    await issueCodes(tester);

    // When
    router.go('/profile');
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Leave without your recovery codes?'), findsOneWidget);
  });

  testWidgets(
    'GivenIssuedCodes_WhenTheRouteIsLeftButStayIsChosen_ThenTheyStay',
    (tester) async {
      // Given
      await issueCodes(tester);
      router.go('/profile');
      await tester.pumpAndSettle();

      // When
      await tester.tap(find.widgetWithText(TextButton, 'Stay'));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Your recovery codes'), findsOneWidget);
      expect(find.text('profile'), findsNothing);
      expect(session(), isA<Authenticated>());
    },
  );

  // Leaving them is leaving under a revoked token, so it signs the person out
  // rather than letting the next screen's request be refused.
  testWidgets('GivenIssuedCodes_WhenTheRouteIsLeftAnyway_ThenTheSessionEnds', (
    tester,
  ) async {
    // Given
    await issueCodes(tester);
    router.go('/profile');
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Leave anyway'));
    await tester.pumpAndSettle();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    expect(find.text('sign-in'), findsOneWidget);
  });

  // A session redirect always wins: asking would strand it behind a dialog.
  testWidgets('GivenIssuedCodes_WhenTheSessionEnds_ThenTheRedirectWins', (
    tester,
  ) async {
    // Given
    await issueCodes(tester);

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signOut(expired: true);
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Leave without your recovery codes?'), findsNothing);
    expect(find.text('sign-in'), findsOneWidget);
  });

  testWidgets(
    'GivenIssuedCodes_WhenSystemBackIsLeftAnyway_ThenTheSessionEnds',
    (tester) async {
      // Given
      await issueCodes(tester);

      // When
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave anyway'));
      await tester.pumpAndSettle();

      // Then
      expect((session() as Unauthenticated).credentialsChanged, isTrue);
      expect(find.text('sign-in'), findsOneWidget);
    },
  );

  // The shell's navigation does not go on to its destination: the sign-out
  // already took the person off the screen.
  testWidgets(
    'GivenIssuedCodes_WhenADestinationIsLeftAnyway_ThenTheSessionEnds',
    (tester) async {
      // Given
      await issueCodes(tester);

      // When
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave anyway'));
      await tester.pumpAndSettle();

      // Then
      expect((session() as Unauthenticated).credentialsChanged, isTrue);
      expect(find.text('sign-in'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    },
  );

  testWidgets('GivenIssuedCodes_WhenSignOutIsLeftAnyway_ThenTheReasonIsKept', (
    tester,
  ) async {
    // Given
    await issueCodes(tester);

    // When
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Leave anyway'));
    await tester.pumpAndSettle();

    // Then
    expect((session() as Unauthenticated).credentialsChanged, isTrue);
    expect(find.text('sign-in'), findsOneWidget);
  });
}
