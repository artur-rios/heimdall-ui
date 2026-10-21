import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/scopes/domain/pending_registration.dart';
import 'package:heimdall_ui/features/scopes/domain/pending_registration_repository.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/pending_registration_list_screen.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_detail_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/idle_expiry_timer.dart';

class _MockPendingRegistrationRepository extends Mock
    implements PendingRegistrationRepository {}

class _MockScopeRepository extends Mock implements ScopeRepository {}

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

final _ada = PendingRegistration(
  id: 'r1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  createdAt: DateTime.utc(2026, 10, 1, 9),
  expiresAt: DateTime.utc(2026, 10, 2, 9),
  attemptsLeft: 7,
  expired: false,
);

final _stale = PendingRegistration(
  id: 'r2',
  name: 'Grace Hopper',
  email: 'grace@example.com',
  createdAt: DateTime.utc(2026, 9, 1, 9),
  expiresAt: DateTime.utc(2026, 9, 2, 9),
  attemptsLeft: 0,
  expired: true,
);

envelope.Page<PendingRegistration> _page({List<PendingRegistration>? items}) {
  final list = items ?? <PendingRegistration>[_ada];

  return envelope.Page<PendingRegistration>(
    items: list,
    pageNumber: 1,
    pageSize: 20,
    totalItems: list.length,
    totalPages: 1,
  );
}

const Size _compact = Size(400, 900);
const Size _medium = Size(800, 900);
const Size _expanded = Size(1400, 900);

void main() {
  late _MockPendingRegistrationRepository repository;
  late _MockScopeRepository scopes;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    Size size = _expanded,
    ThemeData? theme,
    bool scopeOpenedFirst = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(AuthToken(value: _jwt(), expiresAt: DateTime.utc(2030)));

    container = ProviderContainer(
      overrides: <Override>[
        pendingRegistrationRepositoryProvider.overrideWithValue(repository),
        scopeRepositoryProvider.overrideWithValue(scopes),
        tokenStoreProvider.overrideWithValue(store),
        sessionExpiryTimerProvider.overrideWithValue(idleExpiryTimer),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    if (scopeOpenedFirst) {
      await container.read(scopeDetailControllerProvider('s1').notifier).load();
    }

    router = GoRouter(
      initialLocation: '/scopes/s1/pending-registrations',
      routes: <RouteBase>[
        GoRoute(
          path: '/scopes',
          builder: (context, state) => const Scaffold(body: Text('listing')),
        ),
        GoRoute(
          path: '/scopes/:scopeId/pending-registrations',
          builder: (context, state) => PendingRegistrationListScreen(
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

  void answerListWith(Result<envelope.Page<PendingRegistration>> result) {
    when(
      () => repository.list(
        's1',
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// The table scrolls sideways, so the control is brought into view first.
  Future<void> tapAfterScrolling(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockPendingRegistrationRepository();
    scopes = _MockScopeRepository();
    when(
      () => scopes.getById('s1', includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer(
      (_) async =>
          const Success<Scope>(Scope(id: 's1', name: 'Acme', description: '')),
    );
    store = InMemoryTokenStore();
  });

  testWidgets('GivenADeepLink_WhenTheScopeLoads_ThenItsNameIsShown', (
    tester,
  ) async {
    // Given — the scope's page was never opened in this session.
    answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('s1'), findsNothing);
  });

  testWidgets('GivenTheScopeAlreadyRead_WhenOpened_ThenItIsNotReadAgain', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));

    // When
    await pump(tester, scopeOpenedFirst: true);

    // Then
    expect(find.text('Acme'), findsOneWidget);
    verify(
      () => scopes.getById('s1', includeDeleted: any(named: 'includeDeleted')),
    ).called(1);
  });

  testWidgets(
    'GivenRegistrations_WhenOpened_ThenEachShowsItsAddressExpiryAndAttemptsLeft',
    (tester) async {
      // Given
      answerListWith(
        Success<envelope.Page<PendingRegistration>>(
          _page(items: <PendingRegistration>[_ada, _stale]),
        ),
      );

      // When
      await pump(tester);

      // Then
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text('grace@example.com'), findsOneWidget);
      expect(find.text('Attempts left'), findsOneWidget);
      expect(find.text('Expires'), findsOneWidget);
      expect(find.text('Signed up'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Expired'), findsOneWidget);
    },
  );

  testWidgets('GivenRegistrations_WhenOpened_ThenTheExplanationIsShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(
      find.text(
        'These people signed up but have not confirmed yet. Discarding a '
        'registration makes its emailed link stop working; the person may '
        'sign up again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenNoneWaiting_WhenOpened_ThenItSaysSo', (tester) async {
    // Given
    answerListWith(
      Success<envelope.Page<PendingRegistration>>(
        _page(items: const <PendingRegistration>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('No pending registrations.'), findsOneWidget);
    expect(
      find.text('Nobody is waiting to confirm a sign-up for this scope.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenAMissingScope_WhenOpened_ThenTheScopeIsReportedGone', (
    tester,
  ) async {
    // Given — AF-35c
    answerListWith(
      const FailureResult<envelope.Page<PendingRegistration>>(
        Failure(kind: FailureKind.notFound, errors: <String>['No scope.']),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Back to scopes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  testWidgets('GivenARefusedList_WhenOpened_ThenTheForbiddenStateIsShown', (
    tester,
  ) async {
    // Given — AF-35b: retrying would only be refused again.
    answerListWith(
      const FailureResult<envelope.Page<PendingRegistration>>(
        Failure(kind: FailureKind.forbidden, errors: <String>['Forbidden.']),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Not available for your role'), findsOneWidget);
    expect(
      find.text(
        'This scope is not one you administer. Nothing is wrong with your '
        'session.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('GivenTheForbiddenState_WhenBackToScopesIsTapped_ThenItLeaves', (
    tester,
  ) async {
    // Given
    answerListWith(
      const FailureResult<envelope.Page<PendingRegistration>>(
        Failure(kind: FailureKind.forbidden, errors: <String>['Forbidden.']),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.text('Back to scopes'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('listing'), findsOneWidget);
  });

  testWidgets('GivenATransportFailure_WhenOpened_ThenRetryIsOffered', (
    tester,
  ) async {
    // Given — AF-35f
    answerListWith(
      const FailureResult<envelope.Page<PendingRegistration>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);
    answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));

    // When
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets(
    'GivenARegistration_WhenDiscardIsOffered_ThenTheDialogNamesTheAddress',
    (tester) async {
      // Given
      answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));
      await pump(tester);

      // When
      await tapAfterScrolling(
        tester,
        find.byTooltip('Discard the registration for ada@example.com'),
      );

      // Then
      expect(
        find.text('Discard the registration for ada@example.com?'),
        findsOneWidget,
      );
      expect(
        find.text('Its confirmation link will stop working.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenARegistration_WhenDiscardIsCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given — AF-35e
    answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.byTooltip('Discard the registration for ada@example.com'),
    );

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(() => repository.discard(any(), any()));
  });

  testWidgets(
    'GivenARegistration_WhenDiscardIsConfirmed_ThenItIsDiscardedAndTheNoticeShows',
    (tester) async {
      // Given
      answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));
      when(() => repository.discard('s1', 'r1'))
          .thenAnswer((_) async => const Success<void>(null));
      await pump(tester);
      await tapAfterScrolling(
        tester,
        find.byTooltip('Discard the registration for ada@example.com'),
      );

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      // Then
      verify(() => repository.discard('s1', 'r1')).called(1);
      expect(find.text('Registration discarded.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenARefusedDiscard_WhenConfirmed_ThenTheErrorShowsAboveTheList',
    (tester) async {
      // Given — AF-35b
      answerListWith(Success<envelope.Page<PendingRegistration>>(_page()));
      when(() => repository.discard('s1', 'r1')).thenAnswer(
        (_) async => const FailureResult<void>(
          Failure(
            kind: FailureKind.forbidden,
            errors: <String>['You are not an owner of the target scope.'],
          ),
        ),
      );
      await pump(tester);
      await tapAfterScrolling(
        tester,
        find.byTooltip('Discard the registration for ada@example.com'),
      );

      // When
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      // Then
      expect(
        find.text('You are not an owner of the target scope.'),
        findsOneWidget,
      );
      expect(find.text('ada@example.com'), findsOneWidget);
    },
  );

  testWidgets('GivenADiscardInFlight_WhenRendered_ThenEveryDiscardIsDisabled', (
    tester,
  ) async {
    // Given
    answerListWith(
      Success<envelope.Page<PendingRegistration>>(
        _page(items: <PendingRegistration>[_ada, _stale]),
      ),
    );
    final deleted = Completer<Result<void>>();
    when(() => repository.discard('s1', 'r1'))
        .thenAnswer((_) => deleted.future);
    await pump(tester);
    await tapAfterScrolling(
      tester,
      find.byTooltip('Discard the registration for ada@example.com'),
    );

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pump();

    // Then
    for (final email in <String>['ada@example.com', 'grace@example.com']) {
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Discard the registration for $email'),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    }
    deleted.complete(const Success<void>(null));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'GivenALongNameAt1024_WhenDiscardIsTapped_ThenItIsOnScreenAndAsks',
    (tester) async {
      // Given — a registrant may choose a name of up to 200 characters.
      answerListWith(
        Success<envelope.Page<PendingRegistration>>(
          _page(
            items: <PendingRegistration>[
              PendingRegistration(
                id: 'r3',
                name: 'N' * 200,
                email: 'long@example.com',
                createdAt: DateTime.utc(2026, 10, 1, 9),
                expiresAt: DateTime.utc(2026, 10, 2, 9),
                attemptsLeft: 7,
                expired: true,
              ),
            ],
          ),
        ),
      );
      await pump(tester, size: const Size(1024, 768));
      final discard = find.byTooltip(
        'Discard the registration for long@example.com',
      );

      // When — no scrolling first.
      final at = tester.getRect(discard);
      await tester.tap(discard);
      await tester.pumpAndSettle();

      // Then
      expect(at.right, lessThanOrEqualTo(1024));
      expect(at.bottom, lessThanOrEqualTo(768));
      expect(
        find.text('Discard the registration for long@example.com?'),
        findsOneWidget,
      );
    },
  );

  for (final (name, size, theme) in <(String, Size, ThemeData Function())>[
    ('Compact', _compact, buildLightTheme),
    ('Medium', _medium, buildLightTheme),
    ('Expanded', _expanded, buildLightTheme),
    ('Dark', _expanded, buildDarkTheme),
    ('CompactDark', _compact, buildDarkTheme),
  ]) {
    testWidgets('GivenA${name}Window_WhenListed_ThenTheRegistrationIsShown', (
      tester,
    ) async {
      // Given
      answerListWith(
        Success<envelope.Page<PendingRegistration>>(
          _page(items: <PendingRegistration>[_ada, _stale]),
        ),
      );

      // When
      await pump(tester, size: size, theme: theme());

      // Then
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
