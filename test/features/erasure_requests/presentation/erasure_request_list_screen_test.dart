import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/erasure_request_repository.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';
import 'package:heimdall_ui/features/erasure_requests/presentation/erasure_request_list_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockErasureRequestRepository extends Mock
    implements ErasureRequestRepository {}

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

const _subjectId = '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c';

final _blocked = OutstandingErasure(
  subjectId: _subjectId,
  isGoogleUser: false,
  requestedAt: DateTime.utc(2026, 9, 1),
  dueAt: DateTime.utc(2026, 10, 1),
  overdue: true,
  blockedReason: 'The subject is the last owner of a scope.',
);

envelope.Page<OutstandingErasure> _page({List<OutstandingErasure>? items}) {
  final list = items ?? <OutstandingErasure>[_blocked];

  return envelope.Page<OutstandingErasure>(
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
  late _MockErasureRequestRepository repository;
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
        erasureRequestRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();

    router = GoRouter(
      initialLocation: '/erasure-requests',
      routes: <RouteBase>[
        GoRoute(
          path: '/erasure-requests',
          builder: (context, state) => const ErasureRequestListScreen(),
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

  void answerListWith(Result<envelope.Page<OutstandingErasure>> result) {
    when(
      () => repository.list(
        overdueOnly: any(named: 'overdueOnly'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockErasureRequestRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenRequests_WhenOpened_ThenEachShowsItsSubjectAndDeadline', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<OutstandingErasure>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text(_subjectId), findsOneWidget);
    expect(find.text('Person'), findsWidgets);
    expect(find.text('Overdue'), findsOneWidget);
    expect(
      find.text('The subject is the last owner of a scope.'),
      findsOneWidget,
    );
  });

  testWidgets('GivenRequests_WhenOpened_ThenTheNoNamesNoteIsShown', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<OutstandingErasure>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(
      find.text(
        'Names and email addresses are not shown: these people have asked to '
        'be erased.',
      ),
      findsOneWidget,
    );
  });

  // AF-32a
  testWidgets('GivenNoRequests_WhenOpened_ThenTheEmptyStateIsShown', (
    tester,
  ) async {
    // Given
    answerListWith(
      Success<envelope.Page<OutstandingErasure>>(
        _page(items: const <OutstandingErasure>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('No outstanding erasure requests.'), findsOneWidget);
  });

  // AF-32b
  testWidgets(
    'GivenOverdueOnly_WhenNoneAreOverdue_ThenTheFilteredEmptyStateIsShown',
    (tester) async {
      // Given
      answerListWith(Success<envelope.Page<OutstandingErasure>>(_page()));
      await pump(tester);
      answerListWith(
        Success<envelope.Page<OutstandingErasure>>(
          _page(items: const <OutstandingErasure>[]),
        ),
      );

      // When
      await tester.tap(find.widgetWithText(FilterChip, 'Overdue only'));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Nothing is overdue.'), findsOneWidget);
      verify(() => repository.list(overdueOnly: true, pageNumber: 1)).called(1);
    },
  );

  // AF-32c
  testWidgets('GivenARefusedListing_WhenOpened_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerListWith(
      const FailureResult<envelope.Page<OutstandingErasure>>(
        Failure(kind: FailureKind.forbidden, errors: <String>['Forbidden.']),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Forbidden.'), findsOneWidget);
  });

  // AF-32h
  testWidgets('GivenATransportFailure_WhenOpened_ThenRetryIsOffered', (
    tester,
  ) async {
    // Given
    answerListWith(
      const FailureResult<envelope.Page<OutstandingErasure>>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester);
    answerListWith(Success<envelope.Page<OutstandingErasure>>(_page()));

    // When
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text(_subjectId), findsOneWidget);
  });

  testWidgets('GivenACopyControl_WhenTapped_ThenTheIdIsOnTheClipboard', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<OutstandingErasure>>(_page()));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }

        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);

    // When — the table scrolls sideways, so the control is brought into view
    await tester.ensureVisible(find.byTooltip('Copy the identifier'));
    await tester.tap(find.byTooltip('Copy the identifier'));
    await tester.pump();

    // Then
    expect(copied, _subjectId);
    expect(find.text('Identifier copied.'), findsOneWidget);
  });

  testWidgets('GivenRequests_WhenOpened_ThenReapplyIsOfferedButNotYetWired', (
    tester,
  ) async {
    // Given
    answerListWith(Success<envelope.Page<OutstandingErasure>>(_page()));

    // When
    await pump(tester);

    // Then
    expect(find.text('Re-apply erasures'), findsOneWidget);
  });

  for (final (name, size, theme) in <(String, Size, ThemeData Function())>[
    ('Compact', _compact, buildLightTheme),
    ('Medium', _medium, buildLightTheme),
    ('Expanded', _expanded, buildLightTheme),
    ('Dark', _expanded, buildDarkTheme),
    ('CompactDark', _compact, buildDarkTheme),
  ]) {
    testWidgets('GivenA${name}Window_WhenListed_ThenTheRequestIsShown', (
      tester,
    ) async {
      // Given
      answerListWith(Success<envelope.Page<OutstandingErasure>>(_page()));

      // When
      await pump(tester, size: size, theme: theme());

      // Then
      expect(find.text(_subjectId), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
