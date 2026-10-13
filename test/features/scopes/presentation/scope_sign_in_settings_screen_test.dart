import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/shared/widgets/failure_banner.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_sign_in_settings_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

/// A token naming a person of [role]: 1 System Admin, 2 Scope Admin.
String _jwt({int role = 1}) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-1',
        'email': 'admin@example.com',
        'role': role,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  ownerIds: <String>['person-1'],
);

const _googleOff = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  ownerIds: <String>['person-1'],
);

const _linked = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  emailVerificationUrl: 'https://acme.example/verify-email',
  passwordResetUrl: 'https://acme.example/password-reset',
);

const _open = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  selfRegistrationEnabled: true,
  emailVerificationUrl: 'https://acme.example/verify-email',
);

const _deleted = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  isDeleted: true,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockScopeRepository repository;
  late _MockGoogleUserRepository googleUsers;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    int role = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(
      AuthToken(
        value: _jwt(role: role),
        expiresAt: DateTime.utc(2030),
      ),
    );

    container = ProviderContainer(
      overrides: <Override>[
        scopeRepositoryProvider.overrideWithValue(repository),
        googleUserRepositoryProvider.overrideWithValue(googleUsers),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/sign-in-settings',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId',
          builder: (context, state) => const Scaffold(body: Text('scope')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/sign-in-settings',
          builder: (context, state) => ScopeSignInSettingsScreen(
            scopeId: state.pathParameters['scopeId']!,
          ),
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

  void answerGetWith(Result<Scope> result) {
    when(
      () => repository.getById(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Brings a control into view before tapping it.
  Future<void> tapAfterScrolling(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void answerGoogleWith(Result<Scope> result) {
    when(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerCountWith(Result<int> result) {
    when(() => googleUsers.countIn(any())).thenAnswer((_) async => result);
  }

  void answerSignUpWith(Result<Scope> result) {
    when(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerLinksWith(Result<Scope> result) {
    when(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockScopeRepository();
    googleUsers = _MockGoogleUserRepository();
    store = InMemoryTokenStore();
    answerCountWith(const Success<int>(0));
  });

  testWidgets('GivenAScope_WhenOpened_ThenTheGoogleControlReflectsIt', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester);

    // Then
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Google Sign-In'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('GivenGoogleSignInOff_WhenTurnedOn_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_googleOff));
    answerGoogleWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // Then
    verify(() => repository.setGoogleSignIn(id: 'scope-1', enabled: true))
        .called(1);
  });

  // AF-15b — the accounts already in the scope are named before anything is
  // sent.
  testWidgets('GivenGoogleUsersPresent_WhenTurnedOff_ThenTheLossIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(3));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // Then
    expect(
      find.textContaining('3 Google accounts already in this scope'),
      findsOneWidget,
    );
  });

  testWidgets('GivenOneGoogleUser_WhenTurnedOff_ThenTheWarningIsSingular', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(1));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // Then
    expect(
      find.textContaining('1 Google account already in this scope'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheWarning_WhenConfirmed_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(3));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.setGoogleSignIn(id: 'scope-1', enabled: false))
        .called(1);
  });

  testWidgets('GivenTheWarning_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(3));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  // Nothing will stop working, so nothing needs explaining.
  testWidgets('GivenNoGoogleUsers_WhenTurnedOff_ThenNoWarningIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_googleOff));
    answerCountWith(const Success<int>(0));
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // Then
    verify(() => repository.setGoogleSignIn(id: 'scope-1', enabled: false))
        .called(1);
  });

  // A count that cannot be read warns anyway rather than staying quiet.
  testWidgets('GivenAnUnreadableCount_WhenTurnedOff_ThenTheWarningStillShows', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_googleOff));
    answerCountWith(
      const FailureResult<int>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // Then
    expect(find.text('Turn Google Sign-In off?'), findsOneWidget);
  });

  // AF-15a — the refusal is shown and the control stays where the API has it.
  testWidgets('GivenARefusedToggle_WhenAttempted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_googleOff));
    answerGoogleWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['That scope is not active.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tapAfterScrolling(
      tester,
      find.widgetWithText(SwitchListTile, 'Google Sign-In'),
    );

    // Then
    expect(find.text('That scope is not active.'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Google Sign-In'),
          )
          .value,
      isFalse,
    );
  });

  // AF-12d — a deleted scope cannot be changed from here.
  testWidgets('GivenADeletedScope_WhenRendered_ThenTheControlIsDisabled', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Google Sign-In'),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('GivenAScope_WhenOpened_ThenItsWaysInAreShown', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_open));

    // When
    await pump(tester);

    // Then
    final signUp = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Self-registration'),
    );
    expect(signUp.value, isTrue);
    expect(find.text('https://acme.example/verify-email'), findsOneWidget);
  });

  // AF-31f
  testWidgets('GivenNoVerificationLink_WhenSignUpOpened_ThenItAsksFirst', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Open self-registration?'), findsOneWidget);
    expect(
      find.textContaining("link to Heimdall's default page"),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheOpenWarning_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  testWidgets('GivenTheOpenWarning_WhenConfirmed_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerSignUpWith(const Success<Scope>(_open));
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await tester.pumpAndSettle();

    // Then
    verify(() => repository.setSelfRegistration(id: 'scope-1', enabled: true))
        .called(1);
  });

  testWidgets('GivenAVerificationLink_WhenSignUpOpened_ThenItDoesNotAsk', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_linked));
    answerSignUpWith(const Success<Scope>(_open));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Open self-registration?'), findsNothing);
    verify(() => repository.setSelfRegistration(id: 'scope-1', enabled: true))
        .called(1);
  });

  // AF-31g
  testWidgets('GivenSignUpOpen_WhenClosed_ThenTheLossIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_open));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Close self-registration?'), findsOneWidget);
    expect(find.textContaining('will not be able to finish'), findsOneWidget);
  });

  testWidgets('GivenTheCloseWarning_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_open));
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  // AF-31c
  testWidgets('GivenARefusedSignUpToggle_WhenAttempted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_linked));
    answerSignUpWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.forbidden,
          errors: <String>['You do not own this scope.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('You do not own this scope.'), findsOneWidget);
  });

  testWidgets('GivenEditedLinks_WhenSaved_ThenBothAreSent', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_linked));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      'https://acme.example/verify-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password-reset link'),
      'https://acme.example/password-reset',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.setEmailLinks(
        id: 'scope-1',
        emailVerificationUrl: 'https://acme.example/verify-email',
        passwordResetUrl: 'https://acme.example/password-reset',
      ),
    ).called(1);
    expect(find.text('Saved.'), findsOneWidget);
  });

  // AF-31e
  testWidgets('GivenARelativeLink_WhenSaved_ThenNothingIsSent', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      '/verify-email',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('Enter a full link starting with https:// or http://.'),
      findsOneWidget,
    );
    verifyNever(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    );
  });

  // AF-31e
  testWidgets('GivenAnOverlongLink_WhenSaved_ThenItIsReportedNotTruncated', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final overlong = 'https://acme.example/${'a' * 2050}';

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      overlong,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Use at most 2048 characters.'), findsOneWidget);
    verifyNever(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    );
  });

  // AF-31d
  testWidgets('GivenRefusedLinks_WhenSaved_ThenApiErrorsAndInputAreKept', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The email link must be an absolute URL.'],
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      'https://acme.example/verify-email',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('The email link must be an absolute URL.'),
      findsOneWidget,
    );
    expect(find.text('https://acme.example/verify-email'), findsOneWidget);
  });

  // AF-31i
  testWidgets('GivenANetworkFailureOnSave_WhenSaved_ThenRetryAndInputAreKept', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      'https://acme.example/verify-email',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(RetryBanner), findsOneWidget);
    expect(find.byType(ErrorBanner), findsNothing);
    expect(find.text('https://acme.example/verify-email'), findsOneWidget);
  });

  testWidgets('GivenEditedLinks_WhenCancelled_ThenTheSavedOnesReturn', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_linked));
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      'https://elsewhere.example/x',
    );

    // When
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('https://acme.example/verify-email'), findsOneWidget);
    expect(find.text('https://elsewhere.example/x'), findsNothing);
  });

  // AF-31b
  testWidgets('GivenADeletedScope_WhenOpened_ThenNothingCanChange', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const Success<Scope>(
        Scope(id: 'scope-1', name: 'Acme', description: '', isDeleted: true),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This scope is deleted.'), findsOneWidget);
    final signUp = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Self-registration'),
    );
    expect(signUp.onChanged, isNull);
    expect(find.text('Edit'), findsNothing);
  });

  // AF-31a
  testWidgets('GivenAMissingScope_WhenOpened_ThenNotFoundIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Scope not found'), findsOneWidget);
  });

  // AF-31h
  testWidgets('GivenATransportFailure_WhenOpened_ThenRetryIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.byType(RetryBanner), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheSettingsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('Self-registration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheSettingsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Self-registration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheSettingsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Email links'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('GivenScopeSettings_WhenSummarised_ThenEachIsNamed', () {
    // Given / When
    final summary = signInSettingsSummary(_open);

    // Then
    expect(summary, 'Google off · Self-registration on · Custom email links');
  });
}
