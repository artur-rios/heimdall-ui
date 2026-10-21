import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/verification_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/pump_app.dart';
import '../../../support/jwt.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// A token naming a User. The JWT says nothing about verification — the API
/// reports that alongside the token, which is where AF-05e reads it from.
final String _jwt = testJwt(sub: 'id', email: 'a@b.c', role: 3);

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  /// [emailVerified] is what the API said when it issued the token; `null`
  /// stands for no session at all.
  Future<void> pump(
    WidgetTester tester, {
    bool? emailVerified,
    ThemeData? theme,
  }) async {
    container = await pumpApp(
      tester,
      store: store,
      token: emailVerified == null
          ? null
          : testToken(_jwt, emailVerified: emailVerified),
      theme: theme,
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
      home: const Scaffold(body: VerificationBanner()),
    );
  }

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
    when(() => repository.resendVerificationEmail())
        .thenAnswer((_) async => const Success<void>(null));
  });

  // AF-05e — the prompt an unverified authenticated user sees.
  testWidgets('GivenUnverifiedSession_WhenRendered_ThenThePromptIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, emailVerified: false);

    // Then
    expect(
      find.text('Your email address is not verified yet.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenVerifiedSession_WhenRendered_ThenNothingIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, emailVerified: true);

    // Then
    expect(find.text('Your email address is not verified yet.'), findsNothing);
  });

  testWidgets('GivenNoSession_WhenRendered_ThenNothingIsShown', (tester) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Your email address is not verified yet.'), findsNothing);
  });

  // A response that said nothing is not evidence of an unverified address, so
  // the prompt stays quiet rather than nagging on data it does not have.
  testWidgets(
    'GivenATokenStoredBeforeTheApiReportedIt_WhenRendered_ThenNothingIsShown',
    (tester) async {
      // Given
      await store.write(
        AuthToken.fromJson(<String, dynamic>{
          'value': _jwt,
          'expiresAt': '2030-01-01T00:00:00.000Z',
        }),
      );

      // When
      await pump(tester);

      // Then
      expect(
        find.text('Your email address is not verified yet.'),
        findsNothing,
      );
    },
  );

  testWidgets('GivenThePrompt_WhenResendTapped_ThenTheApiIsCalled', (
    tester,
  ) async {
    // Given
    await pump(tester, emailVerified: false);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Resend'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.resendVerificationEmail()).called(1);
  });

  testWidgets('GivenAcceptedResend_WhenSent_ThenConfirmationIsShown', (
    tester,
  ) async {
    // Given
    await pump(tester, emailVerified: false);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Resend'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('A new verification email is on its way.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenRejectedResend_WhenSent_ThenTheApiErrorIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.resendVerificationEmail()).thenAnswer(
      (_) async => const FailureResult<void>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['This address is already verified.'],
        ),
      ),
    );
    await pump(tester, emailVerified: false);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Resend'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('This address is already verified.'), findsOneWidget);
  });

  // AF-05f — the API's account-email budget answers 429 with Retry-After.
  // The message is shown, and the control waits that long before offering a
  // send that would only be refused again.
  testWidgets('GivenACooldown_WhenResendRefused_ThenResendWaitsRetryAfter', (
    tester,
  ) async {
    // Given
    when(() => repository.resendVerificationEmail())
        .thenAnswer((_) async => const FailureResult<void>(_cooldown));
    await pump(tester, emailVerified: false);

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Resend'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text(_cooldown.errors.single), findsOneWidget);
    final button = find.widgetWithText(TextButton, 'Resend');
    expect(tester.widget<TextButton>(button).onPressed, isNull);

    await tester.pump(const Duration(seconds: 119));
    expect(tester.widget<TextButton>(button).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  // AF-05e — and it is dismissible.
  testWidgets('GivenThePrompt_WhenDismissed_ThenItIsGone', (tester) async {
    // Given
    await pump(tester, emailVerified: false);

    // When
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Your email address is not verified yet.'), findsNothing);
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenThePromptIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, emailVerified: false, theme: buildDarkTheme());

    // Then
    expect(
      find.text('Your email address is not verified yet.'),
      findsOneWidget,
    );
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
