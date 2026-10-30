import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/verify_email_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/jwt.dart';
import '../../../support/pump_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    String? token = 'verification-token',
    bool signedIn = false,
    Size size = const Size(400, 900),
    ThemeData? theme,
  }) async {
    await pumpApp(
      tester,
      size: size,
      theme: theme,
      store: store,
      token: signedIn
          ? testToken(testJwt(sub: 'id', email: 'a@b.c', role: 3))
          : null,
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
      routerFor: (_) => router = GoRouter(
        initialLocation: token == null
            ? '/verify-email'
            : '/verify-email?token=$token',
        routes: <RouteBase>[
          GoRoute(
            path: '/verify-email',
            builder: (context, state) =>
                VerifyEmailScreen(token: state.uri.queryParameters['token']),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('login')),
          ),
        ],
      ),
    );
  }

  void answerVerifyWith(Result<List<String>> result) {
    when(() => repository.verifyEmail(token: any(named: 'token')))
        .thenAnswer((_) async => result);
  }

  void answerResendWith(Result<void> result) {
    when(() => repository.resendVerificationEmail())
        .thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAVerificationLink_WhenOpened_ThenTheTokenIsVerified', (
    tester,
  ) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));

    // When
    await pump(tester);

    // Then
    verify(() => repository.verifyEmail(token: 'verification-token')).called(1);
  });

  testWidgets('GivenAcceptedToken_WhenOpened_ThenSuccessIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));

    // When
    await pump(tester);

    // Then
    expect(find.text('Your email is verified'), findsOneWidget);
  });

  // AF-05d — the API's own wording is what says it was already verified.
  testWidgets('GivenAlreadyVerified_WhenOpened_ThenTheApiMessageIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const Success<List<String>>(<String>[
        'This address was already verified.',
      ]),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('This address was already verified.'), findsOneWidget);
  });

  testWidgets('GivenNoSession_WhenVerified_ThenSignInIsOffered', (
    tester,
  ) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('GivenASession_WhenVerified_ThenHomeIsOffered', (tester) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));
    answerResendWith(const Success<void>(null));
    await pump(tester, signedIn: true);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('home'), findsOneWidget);
  });

  // #158 — the controller outlives the screen, so a second visit must start
  // from a clean state rather than from the previous visit's answer. The
  // first frame can still draw the old state; this checks it is gone as soon
  // as the screen has settled itself, while the new answer is pending.
  testWidgets(
    'GivenAVerifiedLink_WhenASecondLinkIsOpened_ThenTheOldResultIsNotShown',
    (tester) async {
      // Given
      answerVerifyWith(const Success<List<String>>(<String>[]));
      await pump(tester, token: 'token-a');
      expect(find.text('Your email is verified'), findsOneWidget);
      router.go('/login');
      await tester.pumpAndSettle();
      final pending = Completer<Result<List<String>>>();
      when(() => repository.verifyEmail(token: 'token-b'))
          .thenAnswer((_) => pending.future);

      // When
      router.go('/verify-email?token=token-b');
      await tester.pump();
      await tester.pump();

      // Then
      expect(find.text('Your email is verified'), findsNothing);
      pending.complete(const Success<List<String>>(<String>[]));
      await tester.pumpAndSettle();
      expect(find.text('Your email is verified'), findsOneWidget);
    },
  );

  // AF-05a — a link with no token verifies nothing and offers the resend.
  testWidgets('GivenNoToken_WhenOpened_ThenNoRequestIsMade', (tester) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));

    // When
    await pump(tester, token: null);

    // Then
    verifyNever(() => repository.verifyEmail(token: any(named: 'token')));
  });

  testWidgets('GivenNoToken_WhenOpened_ThenTheLinkIsCalledIncomplete', (
    tester,
  ) async {
    // Given / When
    await pump(tester, token: null);

    // Then
    expect(find.text('This link is incomplete'), findsOneWidget);
  });

  testWidgets('GivenNoTokenAndASession_WhenOpened_ThenResendIsOffered', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));

    // When
    await pump(tester, token: null, signedIn: true);

    // Then
    expect(
      find.widgetWithText(FilledButton, 'Send a new email'),
      findsOneWidget,
    );
  });

  // The resend endpoint reads the person from the bearer token, so an
  // anonymous caller is sent to sign in rather than offered a dead control.
  testWidgets('GivenNoTokenAndNoSession_WhenOpened_ThenSignInIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, token: null);

    // Then
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send a new email'), findsNothing);
  });

  // AF-05b — the API refuses the token, and the resend is the way on.
  testWidgets('GivenRejectedToken_WhenOpened_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The verification token has expired.'],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('The verification token has expired.'), findsOneWidget);
  });

  testWidgets('GivenRejectedTokenAndASession_WhenOpened_ThenResendIsOffered', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.validation, errors: <String>['No good.']),
      ),
    );
    answerResendWith(const Success<void>(null));

    // When
    await pump(tester, signedIn: true);

    // Then
    expect(
      find.widgetWithText(FilledButton, 'Send a new email'),
      findsOneWidget,
    );
  });

  // AF-05c — the resend is sent and confirmed neutrally.
  testWidgets('GivenASession_WhenResendRequested_ThenTheApiIsCalled', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.validation, errors: <String>['No good.']),
      ),
    );
    answerResendWith(const Success<void>(null));
    await pump(tester, signedIn: true);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Send a new email'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.resendVerificationEmail()).called(1);
  });

  testWidgets('GivenAcceptedResend_WhenRequested_ThenConfirmationIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.validation, errors: <String>['No good.']),
      ),
    );
    answerResendWith(const Success<void>(null));
    await pump(tester, signedIn: true);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Send a new email'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('A new verification email is on its way. Check your inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenRejectedResend_WhenRequested_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.validation, errors: <String>['No good.']),
      ),
    );
    answerResendWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['This address is already verified.'],
        ),
      ),
    );
    await pump(tester, signedIn: true);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Send a new email'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('This address is already verified.'), findsOneWidget);
  });

  // AF-05f — the account-email budget's 429 holds the send back for as long
  // as Retry-After says.
  testWidgets('GivenACooldown_WhenResendRefused_ThenSendWaitsRetryAfter', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.validation, errors: <String>['No good.']),
      ),
    );
    answerResendWith(const FailureResult<void>(_cooldown));
    await pump(tester, signedIn: true);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Send a new email'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text(_cooldown.errors.single), findsOneWidget);
    expect(find.text('Try again in 2 minutes.'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Send a new email');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.pump(const Duration(seconds: 120));
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  // FR-UX-09 — however long the API asks for, the pause is held to a day.
  testWidgets('GivenAHugeRetryAfter_WhenResendRefused_ThenSendWaitsADay', (
    tester,
  ) async {
    // Given
    answerVerifyWith(
      const FailureResult<List<String>>(
        Failure(kind: FailureKind.validation, errors: <String>['No good.']),
      ),
    );
    answerResendWith(
      FailureResult<void>(
        Failure(
          kind: FailureKind.rateLimited,
          errors: _cooldown.errors,
          retryAfter: const Duration(days: 365),
        ),
      ),
    );
    await pump(tester, signedIn: true);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Send a new email'));
    await tester.pumpAndSettle();

    // Then
    final button = find.widgetWithText(FilledButton, 'Send a new email');
    await tester.pump(const Duration(hours: 23, minutes: 59));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.pump(const Duration(minutes: 1));
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('GivenCompactWidth_WhenRendered_ThenTheOutcomeIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));

    // When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(find.text('Your email is verified'), findsOneWidget);
  });

  testWidgets('GivenMediumWidth_WhenRendered_ThenTheOutcomeIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));

    // When
    await pump(tester, size: const Size(800, 900));

    // Then
    expect(find.text('Your email is verified'), findsOneWidget);
  });

  testWidgets('GivenExpandedWidth_WhenRendered_ThenTheOutcomeIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));

    // When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(find.text('Your email is verified'), findsOneWidget);
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheOutcomeIsShown', (
    tester,
  ) async {
    // Given
    answerVerifyWith(const Success<List<String>>(<String>[]));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Your email is verified'), findsOneWidget);
  });
}

const Failure _cooldown = Failure(
  kind: FailureKind.rateLimited,
  errors: <String>[
    'An email of this kind was sent to you recently. Try again in a few '
        'minutes.',
  ],
  retryAfter: Duration(seconds: 120),
);
