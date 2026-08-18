import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user.dart';
import 'package:heimdall_ui/features/google_users/domain/google_user_repository.dart';
import 'package:heimdall_ui/features/google_users/presentation/google_user_detail_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGoogleUserRepository extends Mock implements GoogleUserRepository {}

String _jwt() {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': 'person-9',
        'email': 'admin@example.com',
        'role': 1,
      }),
    ),
  );

  return 'header.$payload.signature';
}

const _ada = GoogleUser(
  id: 'google-1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  googleId: '1234567890',
  scopeId: 'scope-1',
);

const _deleted = GoogleUser(
  id: 'google-1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  scopeId: 'scope-1',
  isDeleted: true,
);

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockGoogleUserRepository repository;
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
        googleUserRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/scopes/scope-1/google-users/google-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes/:scopeId/google-users',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/google-users/:googleUserId',
          builder: (context, state) => GoogleUserDetailScreen(
            scopeId: state.pathParameters['scopeId']!,
            googleUserId: state.pathParameters['googleUserId']!,
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

  void answerGetWith(Result<GoogleUser> result) {
    when(
      () => repository.getById(
        scopeId: any(named: 'scopeId'),
        id: any(named: 'id'),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockGoogleUserRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenAGoogleUser_WhenOpened_ThenTheRecordIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('1234567890'), findsOneWidget);
  });

  // AF-28e — nothing here is editable, and the screen says why.
  testWidgets('GivenAGoogleUser_WhenOpened_ThenNothingIsEditable', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.byType(TextFormField), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsNothing);
  });

  testWidgets('GivenAGoogleUser_WhenOpened_ThenTheReadOnlyReasonIsGiven', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(
      find.textContaining('come from Google and cannot be changed here'),
      findsOneWidget,
    );
  });

  // AF-28d — no picture, so the initials stand in.
  testWidgets('GivenNoPicture_WhenOpened_ThenInitialsAreShown', (tester) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester);

    // Then
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('GivenAMissingGoogleUser_WhenOpened_ThenNotFoundIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Google user not found'), findsOneWidget);
  });

  testWidgets('GivenAMissingGoogleUser_WhenBackTapped_ThenTheListingOpens', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Back to the listing'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  testWidgets('GivenAForbiddenGoogleUser_WhenOpened_ThenTheRolePanelIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.forbidden, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
  });

  testWidgets('GivenADeletedGoogleUser_WhenOpened_ThenItIsMarkedDeleted', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_deleted));

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This Google user is deleted'), findsOneWidget);
  });

  testWidgets('GivenATransportFailure_WhenOpened_ThenARetryIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<GoogleUser>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('ada@example.com'), findsWidgets);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheDetailIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('ada@example.com'), findsWidgets);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheDetailIsStillShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<GoogleUser>(_ada));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Ada Lovelace'), findsWidgets);
  });
}
