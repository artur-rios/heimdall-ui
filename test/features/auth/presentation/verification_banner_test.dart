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

/// A token naming a User, with [verified] deciding the claim AF-05e reads.
/// Pass `null` to leave the claim out entirely.
String jwtWith({bool? verified}) {
  final claims = <String, dynamic>{'sub': 'id', 'email': 'a@b.c', 'role': 3};

  if (verified != null) {
    claims['emailVerified'] = verified;
  }

  return 'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';
}

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    String? jwt,
    ThemeData? theme,
  }) async {
    if (jwt != null) {
      await store.write(AuthToken(value: jwt, expiresAt: DateTime.utc(2030)));
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
    await pump(tester, jwt: jwtWith(verified: false));

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
    await pump(tester, jwt: jwtWith(verified: true));

    // Then
    expect(find.text('Your email address is not verified yet.'), findsNothing);
  });

  testWidgets('GivenNoSession_WhenRendered_ThenNothingIsShown', (tester) async {
    // Given / When
    await pump(tester);

    // Then
    expect(find.text('Your email address is not verified yet.'), findsNothing);
  });

  // An absent claim is not evidence of an unverified address, so it stays
  // quiet rather than nagging on data it does not have.
  testWidgets('GivenNoVerificationClaim_WhenRendered_ThenNothingIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, jwt: jwtWith());

    // Then
    expect(find.text('Your email address is not verified yet.'), findsNothing);
  });

  testWidgets('GivenThePrompt_WhenResendTapped_ThenTheApiIsCalled', (
    tester,
  ) async {
    // Given
    await pump(tester, jwt: jwtWith(verified: false));

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
    await pump(tester, jwt: jwtWith(verified: false));

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
    await pump(tester, jwt: jwtWith(verified: false));

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Resend'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('This address is already verified.'), findsOneWidget);
  });

  // AF-05e — and it is dismissible.
  testWidgets('GivenThePrompt_WhenDismissed_ThenItIsGone', (tester) async {
    // Given
    await pump(tester, jwt: jwtWith(verified: false));

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
    await pump(tester, jwt: jwtWith(verified: false), theme: buildDarkTheme());

    // Then
    expect(
      find.text('Your email address is not verified yet.'),
      findsOneWidget,
    );
  });
}
