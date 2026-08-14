import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/password_recovery_screen.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const PasswordRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void answerWith(Result<void> result) {
    when(
      () => repository.requestPasswordRecovery(email: any(named: 'email')),
    ).thenAnswer((_) async => result);
  }

  Future<void> submit(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockAuthRepository();
  });

  testWidgets('GivenRecoveryScreen_WhenSubmitted_ThenTheAddressIsSent', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, 'a@b.c');

    // Then
    verify(() => repository.requestPasswordRecovery(email: 'a@b.c')).called(1);
  });

  testWidgets('GivenAcceptedRequest_WhenSubmitted_ThenConfirmationIsShown', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, 'a@b.c');

    // Then
    expect(find.text('Check your inbox'), findsOneWidget);
  });

  // The confirmation must not repeat the address back, since doing so on a
  // shared screen would be one more place it could be read.
  testWidgets('GivenAcceptedRequest_WhenConfirmed_ThenTheAddressIsNotEchoed', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, 'a@b.c');

    // Then
    expect(find.textContaining('a@b.c'), findsNothing);
  });

  // The neutral confirmation: an address nobody holds is answered identically.
  testWidgets(
    'GivenUnknownAddress_WhenSubmitted_ThenTheSameConfirmationIsShown',
    (tester) async {
      // Given
      answerWith(const Success<void>(null));
      await pump(tester);

      // When
      await submit(tester, 'nobody@nowhere.invalid');

      // Then
      expect(find.text('Check your inbox'), findsOneWidget);
    },
  );

  // AF-03a — an empty address never reaches the API.
  testWidgets('GivenEmptyAddress_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, '');

    // Then
    verifyNever(
      () => repository.requestPasswordRecovery(email: any(named: 'email')),
    );
  });

  // AF-03a — and neither does a malformed one.
  testWidgets('GivenMalformedAddress_WhenSubmitted_ThenTheFieldIsMarked', (
    tester,
  ) async {
    // Given
    answerWith(const Success<void>(null));
    await pump(tester);

    // When
    await submit(tester, 'not-an-address');

    // Then
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  // AF-03b — a transport failure offers a retry and withholds the confirmation.
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
    await submit(tester, 'a@b.c');

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenTransportFailure_WhenSubmitted_ThenNoConfirmationIsShown', (
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
    await submit(tester, 'a@b.c');

    // Then
    expect(find.text('Check your inbox'), findsNothing);
  });

  testWidgets('GivenRejectedRequest_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Email is not in a valid format.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await submit(tester, 'a@b.c');

    // Then
    expect(find.text('Email is not in a valid format.'), findsOneWidget);
  });

  // AF-03c — the control is disabled while the request is in flight.
  testWidgets('GivenRequestInFlight_WhenRendered_ThenSubmitIsDisabled', (
    tester,
  ) async {
    // Given
    final pending = Completer<Result<void>>();
    when(
      () => repository.requestPasswordRecovery(email: any(named: 'email')),
    ).thenAnswer((_) => pending.future);
    await pump(tester);

    // When
    await tester.enterText(find.byType(TextFormField), 'a@b.c');
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

  // AF-03c — and a second tap while it is in flight sends nothing.
  testWidgets('GivenRequestInFlight_WhenTappedAgain_ThenOnlyOneRequestIsSent', (
    tester,
  ) async {
    // Given
    final pending = Completer<Result<void>>();
    when(
      () => repository.requestPasswordRecovery(email: any(named: 'email')),
    ).thenAnswer((_) => pending.future);
    await pump(tester);

    // When
    await tester.enterText(find.byType(TextFormField), 'a@b.c');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Then
    verify(() => repository.requestPasswordRecovery(email: 'a@b.c')).called(1);
    pending.complete(const Success<void>(null));
    await tester.pumpAndSettle();
  });

  testWidgets('GivenCompactWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(
      find.widgetWithText(FilledButton, 'Send reset link'),
      findsOneWidget,
    );
  });

  testWidgets('GivenMediumWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(800, 900));

    // Then
    expect(
      find.widgetWithText(FilledButton, 'Send reset link'),
      findsOneWidget,
    );
  });

  testWidgets('GivenExpandedWidth_WhenRendered_ThenTheFormIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(
      find.widgetWithText(FilledButton, 'Send reset link'),
      findsOneWidget,
    );
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheFormIsShown', (tester) async {
    // Given / When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Forgot your password?'), findsOneWidget);
  });
}
