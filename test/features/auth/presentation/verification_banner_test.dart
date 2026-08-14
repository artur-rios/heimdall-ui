import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/auth/presentation/verification_banner.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// A token naming a User. The JWT says nothing about verification — the API
/// reports that alongside the token, which is where AF-05e reads it from.
final String _jwt =
    'header.'
    '${base64Url.encode(utf8.encode(jsonEncode(<String, dynamic>{'sub': 'id', 'email': 'a@b.c', 'role': 3})))}'
    '.signature';

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
    if (emailVerified != null) {
      await store.write(
        AuthToken(
          value: _jwt,
          expiresAt: DateTime.utc(2030),
          emailVerified: emailVerified,
        ),
      );
    }

    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: const Scaffold(body: VerificationBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
    when(
      () => repository.resendVerificationEmail(),
    ).thenAnswer((_) async => const Success<void>(null));
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
