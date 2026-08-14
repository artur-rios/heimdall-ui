import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/password_reset_screen.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;
  late GoRouter router;

  /// Pumps the screen behind a router, so the actions that leave it — request a
  /// new link, sign in — can be followed rather than only rendered.
  Future<void> pump(
    WidgetTester tester, {
    String? token = 'reset-token',
    Size size = const Size(400, 900),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    router = GoRouter(
      initialLocation: token == null
          ? '/password-reset'
          : '/password-reset?token=$token',
      routes: <RouteBase>[
        GoRoute(
          path: '/password-reset',
          builder: (context, state) =>
              PasswordResetScreen(token: state.uri.queryParameters['token']),
        ),
        GoRoute(
          path: '/password-recovery',
          builder: (context, state) =>
              const Scaffold(body: Text('recovery screen')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('login')),
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

  void answerWith(Result<void> result) {
    when(
      () => repository.resetPassword(
        token: any(named: 'token'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => result);
  }

  Future<void> submit(
    WidgetTester tester,
    String password,
    String confirmation,
  ) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      password,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      confirmation,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Set password'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockAuthRepository();
  });

  testWidgets('GivenAResetLink_WhenSubmitted_ThenTokenAndPasswordAreSent', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, 'new-secret', 'new-secret');

    // Then
    verify(
      () => repository.resetPassword(
        token: 'reset-token',
        newPassword: 'new-secret',
      ),
    ).called(1);
  });

  testWidgets('GivenAcceptedReset_WhenSubmitted_ThenSuccessIsShown', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, 'new-secret', 'new-secret');

    // Then
    expect(find.text('Your password is set'), findsOneWidget);
  });

  testWidgets('GivenAcceptedReset_WhenSigningIn_ThenLoginIsOpened', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);
    await submit(tester, 'new-secret', 'new-secret');

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('login'), findsOneWidget);
  });

  // AF-04a — the link carried no token.
  testWidgets('GivenNoToken_WhenRendered_ThenTheLinkIsCalledIncomplete', (
    tester,
  ) async {
    // Given / When
    await pump(tester, token: null);

    // Then
    expect(find.text('This link is incomplete'), findsOneWidget);
  });

  testWidgets('GivenNoToken_WhenRendered_ThenNoFormIsShown', (tester) async {
    // Given / When
    await pump(tester, token: null);

    // Then
    expect(find.byType(TextFormField), findsNothing);
  });

  // AF-04a — and the way out of it is UI-03.
  testWidgets('GivenNoToken_WhenANewLinkIsRequested_ThenRecoveryIsOpened', (
    tester,
  ) async {
    // Given
    await pump(tester, token: null);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Request a new link'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('recovery screen'), findsOneWidget);
  });

  // AF-04b — the API refuses the token.
  testWidgets('GivenRejectedToken_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The reset token has expired.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await submit(tester, 'new-secret', 'new-secret');

    // Then
    expect(find.text('The reset token has expired.'), findsWidgets);
  });

  testWidgets('GivenRejectedToken_WhenSubmitted_ThenANewLinkIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The reset token has expired.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await submit(tester, 'new-secret', 'new-secret');
    await tester.tap(find.widgetWithText(TextButton, 'Request a new link'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('recovery screen'), findsOneWidget);
  });

  // AF-04c — a mismatched confirmation never reaches the API.
  testWidgets('GivenMismatchedPasswords_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, 'new-secret', 'different');

    // Then
    verifyNever(
      () => repository.resetPassword(
        token: any(named: 'token'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });

  testWidgets(
    'GivenMismatchedPasswords_WhenSubmitted_ThenTheConfirmationIsMarked',
    (tester) async {
      // Given
      answerWith(const Success<void>(null));
      await pump(tester);

      // When
      await submit(tester, 'new-secret', 'different');

      // Then
      expect(find.text('The passwords do not match.'), findsOneWidget);
    },
  );

  // AF-04d — the policy refuses the password, and the field says so.
  testWidgets('GivenRejectedPassword_WhenSubmitted_ThenTheFieldIsMarked', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Password must be at least 8 characters.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await submit(tester, 'short', 'short');

    // Then
    final field = tester.widget<TextField>(
      find
          .descendant(
            of: find.widgetWithText(TextFormField, 'New password'),
            matching: find.byType(TextField),
          )
          .first,
    );
    expect(
      field.decoration?.errorText,
      'Password must be at least 8 characters.',
    );
  });

  testWidgets('GivenTransportFailure_WhenSubmitted_ThenRetryIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await submit(tester, 'new-secret', 'new-secret');

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenResetInFlight_WhenRendered_ThenSubmitIsDisabled', (
    tester,
  ) async {
    // Given
    final pending = Completer<Result<void>>();
    when(
      () => repository.resetPassword(
        token: any(named: 'token'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) => pending.future);
    await pump(tester);

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'new-secret',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'new-secret',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // Then
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete(const Success<void>(null));
    await tester.pumpAndSettle();
  });

  testWidgets('GivenCompactWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(find.widgetWithText(FilledButton, 'Set password'), findsOneWidget);
  });

  testWidgets('GivenMediumWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(800, 900));

    // Then
    expect(find.widgetWithText(FilledButton, 'Set password'), findsOneWidget);
  });

  testWidgets('GivenExpandedWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(find.widgetWithText(FilledButton, 'Set password'), findsOneWidget);
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheFormIsShown', (tester) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.widgetWithText(FilledButton, 'Set password'), findsOneWidget);
  });
}
