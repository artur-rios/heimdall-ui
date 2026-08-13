import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/heimdall_app.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const String _systemAdminJwt =
    'header.'
    'eyJzdWIiOiI2ZjFkM2EwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDEiLCJlbWFpbCI6'
    'ImFkbWluQGV4YW1wbGUuY29tIiwicm9sZSI6MX0.'
    'signature';

void main() {
  late InMemoryTokenStore store;
  late _MockAuthRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = InMemoryTokenStore();
    repository = _MockAuthRepository();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        tokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeimdallApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GivenNoSession_WhenAppStarts_ThenLoginScreenIsShown', (
    tester,
  ) async {
    // Given no stored token

    // When
    await pumpApp(tester);

    // Then
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('GivenStoredSession_WhenAppStarts_ThenHomeScreenIsShown', (
    tester,
  ) async {
    // Given
    await store.write(
      AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
    );

    // When
    await pumpApp(tester);

    // Then
    expect(find.text('Signed in as admin@example.com'), findsOneWidget);
    expect(find.text('System Admin'), findsOneWidget);
  });

  testWidgets('GivenEmptyPassword_WhenSubmitted_ThenNoRequestIsMade', (
    tester,
  ) async {
    // Given
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Enter your password.'), findsOneWidget);
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('GivenRejectedLogin_WhenSubmitted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'wrong')).thenAnswer(
      (_) async => const FailureResult<LoginOutcome>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Invalid credentials'],
        ),
      ),
    );
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrong',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('GivenAcceptedLogin_WhenSubmitted_ThenHomeScreenIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(
        LoggedIn(
          AuthToken(value: _systemAdminJwt, expiresAt: DateTime.utc(2030)),
        ),
      ),
    );
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret',
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Signed in as admin@example.com'), findsOneWidget);
  });
}
