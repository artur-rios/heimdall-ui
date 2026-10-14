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
import 'package:heimdall_ui/features/audit_log/domain/audit_entry.dart';
import 'package:heimdall_ui/features/audit_log/domain/audit_log_repository.dart';
import 'package:heimdall_ui/features/audit_log/presentation/audit_log_controller.dart';
import 'package:heimdall_ui/features/audit_log/presentation/audit_log_screen.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuditLogRepository extends Mock implements AuditLogRepository {}

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

const _actorId = '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c';
const _targetId = 'b7c1d2e3-0000-4000-8000-000000000001';

final _refused = AuditEntry(
  id: 'a1',
  recordedAt: DateTime.utc(2026, 10, 14, 12),
  actorId: _actorId,
  actorRole: Role.scopeAdmin,
  action: 'CreateScopeCommand',
  succeeded: false,
  failureReason: 'You are not an owner of the target scope.',
);

const _noActor = AuditEntry(
  id: 'a2',
  action: 'UpdatePersonCommand',
  succeeded: true,
  targetId: _targetId,
);

envelope.Page<AuditEntry> _page(List<AuditEntry> items) =>
    envelope.Page<AuditEntry>(
      items: items,
      pageNumber: 1,
      pageSize: 20,
      totalItems: items.length,
      totalPages: 1,
    );

void main() {
  late _MockAuditLogRepository repository;
  late InMemoryTokenStore store;
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function(ProviderContainer container)? prepare,
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.write(AuthToken(value: _jwt(), expiresAt: DateTime.utc(2030)));

    container = ProviderContainer(
      overrides: <Override>[
        auditLogRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    await prepare?.call(container);

    router = GoRouter(
      initialLocation: '/audit-log',
      routes: <RouteBase>[
        GoRoute(
          path: '/audit-log',
          builder: (context, state) => const AuditLogScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void answerWith(Result<envelope.Page<AuditEntry>> result) {
    when(
      () => repository.list(
        filter: any(named: 'filter'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUpAll(() {
    registerFallbackValue(const AuditLogFilter());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _MockAuditLogRepository();
    store = InMemoryTokenStore();
  });

  testWidgets('GivenEntries_WhenOpened_ThenEachShowsItsActionOutcomeAndIds', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused, _noActor])));

    // When
    await pump(tester);

    // Then
    expect(find.text('CreateScopeCommand'), findsWidgets);
    expect(find.text('Refused'), findsWidgets);
    expect(
      find.text('You are not an owner of the target scope.'),
      findsOneWidget,
    );
    expect(find.text('6f1c2b9e…'), findsWidgets);
    expect(find.text('Scope Admin'), findsWidgets);
    expect(find.text('None'), findsWidgets);
    expect(find.text('Cleared'), findsNothing);
    expect(find.text('b7c1d2e3…'), findsWidgets);
  });

  testWidgets(
    'GivenACompactWindow_WhenOpened_ThenTheFiltersFoldAndEntriesShow',
    (tester) async {
      // Given
      answerWith(
        Success<envelope.Page<AuditEntry>>(_page([_refused, _noActor])),
      );

      // When
      await pump(tester, size: const Size(360, 640));

      // Then
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(OutlinedButton, 'Filters'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Actor'), findsNothing);
      expect(find.text('CreateScopeCommand').hitTestable(), findsOneWidget);
      expect(find.text('UpdatePersonCommand').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('GivenACompactWindow_WhenFiltersIsTapped_ThenTheFilterBarOpens', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));
    await pump(tester, size: const Size(360, 640));

    // When
    await tester.tap(find.widgetWithText(OutlinedButton, 'Filters'));
    await tester.pumpAndSettle();

    // Then
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'Actor'), findsOneWidget);
    expect(find.text('CreateScopeCommand').hitTestable(), findsOneWidget);
  });

  testWidgets('GivenFoldedFilters_WhenSomeAreSet_ThenTheToggleCountsThem', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));

    // When
    await pump(
      tester,
      size: const Size(360, 640),
      prepare: (container) async {
        final controller = container.read(auditLogControllerProvider.notifier);
        unawaited(controller.setOutcome(false));
        await controller.setAction('CreateScopeCommand');
      },
    );

    // Then
    expect(find.widgetWithText(OutlinedButton, 'Filters (2)'), findsOneWidget);
  });

  testWidgets('GivenAShortWindow_WhenOpened_ThenTheListKeepsRoom', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused, _noActor])));

    final errors = <FlutterErrorDetails>[];
    final reportError = FlutterError.onError;
    FlutterError.onError = errors.add;

    // When
    try {
      await pump(tester, size: const Size(640, 360));
    } finally {
      FlutterError.onError = reportError;
    }

    // Then — the shell's navigation rail overflowing a window this short is a
    // known shell-level issue (M3); nothing of this screen may overflow.
    final rail = tester.renderObject(find.byType(NavigationRail));
    bool inRail(RenderObject? node) =>
        node != null && (identical(node, rail) || inRail(node.parent));
    // An overflow report names the render object that overflowed.
    RenderObject? overflowing(FlutterErrorDetails details) => details
        .informationCollector
        ?.call()
        .map((node) => node.value)
        .whereType<RenderObject>()
        .firstOrNull;
    final screenErrors = errors.where(
      (details) => !inRail(overflowing(details)),
    );
    expect(screenErrors, isEmpty);
    expect(find.text('CreateScopeCommand').hitTestable(), findsOneWidget);
  });

  testWidgets('GivenATable_WhenOpened_ThenItNamesItsColumnsAndDatesOnce', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));

    // When
    await pump(tester);

    // Then
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Action'), findsWidgets);
    expect(find.text('Name'), findsNothing);
    expect(find.textContaining('2026'), findsOneWidget);
  });

  testWidgets('GivenALongRefusalReason_WhenInATable_ThenItWrapsNarrowly', (
    tester,
  ) async {
    // Given
    final reason = List<String>.filled(50, 'Refused because.').join(' ');
    answerWith(
      Success<envelope.Page<AuditEntry>>(
        _page([
          AuditEntry(
            id: 'a3',
            recordedAt: DateTime.utc(2026, 10, 14, 12),
            action: 'CreateScopeCommand',
            succeeded: false,
            failureReason: reason,
          ),
        ]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(tester.getSize(find.text(reason)).width, lessThanOrEqualTo(260));
  });

  testWidgets('GivenAnIdentifier_WhenShown_ThenItIsShortenedWithTheFullTip', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));

    // When
    await pump(tester);

    // Then
    expect(find.text(_actorId), findsNothing);
    expect(find.byTooltip(_actorId), findsOneWidget);
    final targetHeader = find.descendant(
      of: find.byType(DataTable),
      matching: find.text('Target'),
    );
    expect(tester.getTopRight(targetHeader).dx, lessThanOrEqualTo(1400));
  });

  testWidgets(
    'GivenAnActorThatIsNotAnIdentifier_WhenSubmitted_ThenTheFieldSaysSoAndNothingIsSent',
    (tester) async {
      // Given
      answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));
      await pump(tester);
      clearInteractions(repository);

      // When
      await tester.enterText(find.widgetWithText(TextField, 'Actor'), 'bob');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Enter an identifier.'), findsOneWidget);
      verifyNever(
        () => repository.list(
          filter: any(named: 'filter'),
          pageNumber: any(named: 'pageNumber'),
          pageSize: any(named: 'pageSize'),
        ),
      );
    },
  );

  testWidgets(
    'GivenAnEntry_WhenFilterByActorIsChosen_ThenTheListIsNarrowedToThatActor',
    (tester) async {
      // Given
      answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));
      await pump(tester);

      // When
      final button = find.byTooltip('Filter by this actor').first;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Then
      final sent =
          verify(
                () => repository.list(
                  filter: captureAny(named: 'filter'),
                  pageNumber: any(named: 'pageNumber'),
                  pageSize: any(named: 'pageSize'),
                ),
              ).captured.last
              as AuditLogFilter;
      expect(sent.actorId, _actorId);
      expect(find.widgetWithText(TextField, _actorId), findsOneWidget);
    },
  );

  testWidgets('GivenAnEntry_WhenCopyIsChosen_ThenTheIdentifierIsCopied', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));
    await pump(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
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

    // When
    final button = find.byTooltip('Copy the actor').first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    // Then
    expect(copied, _actorId);
    expect(find.text('Identifier copied.'), findsOneWidget);
  });

  testWidgets(
    'GivenAFilterThatMatchesNothing_WhenOpened_ThenItOffersToClearFilters',
    (tester) async {
      // Given
      answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));
      await pump(tester);
      answerWith(Success<envelope.Page<AuditEntry>>(_page(const [])));

      // When
      await tester.tap(find.widgetWithText(ChoiceChip, 'Refused'));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('No entries match these filters.'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Clear filters'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenNoEntriesAtAll_WhenOpened_ThenTheLogIsEmpty', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page(const [])));

    // When
    await pump(tester);

    // Then
    expect(find.text('The audit log is empty.'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('GivenEntries_WhenOpened_ThenTheNoActorNoteIsShown', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));

    // When
    await pump(tester);

    // Then
    expect(
      find.text(
        'An entry shows no actor when the action was anonymous, such as a '
        'sign-in, or when its attribution was cleared — after the attribution '
        'period, or once the person was erased. Filtering by actor cannot find '
        'these.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenAFailure_WhenOpened_ThenTheFiltersStayAndRetryIsOffered', (
    tester,
  ) async {
    // Given
    answerWith(
      const FailureResult<envelope.Page<AuditEntry>>(
        Failure(
          kind: FailureKind.validation,
          errors: ['The range is reversed.'],
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('The range is reversed.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Actor'), findsOneWidget);
  });

  testWidgets('GivenADateRange_WhenShown_ThenTheDatesButtonNamesTheYear', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page(const [])));

    // When
    await pump(
      tester,
      prepare: (container) => container
          .read(auditLogControllerProvider.notifier)
          .setDays(DateTime(2025, 12, 30), DateTime(2026, 1, 2)),
    );

    // Then
    expect(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.textContaining('2025'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.textContaining('2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenARetainedFilter_WhenReentered_ThenTheFieldsShowIt', (
    tester,
  ) async {
    // Given
    answerWith(Success<envelope.Page<AuditEntry>>(_page([_refused])));

    // When
    await pump(
      tester,
      prepare: (container) async {
        final controller = container.read(auditLogControllerProvider.notifier);
        await controller.setAction('CreateScopeCommand');
        controller.setActor(_actorId);
        for (var i = 0; i < 10; i++) {
          await Future<void>.value();
        }
        controller.setTarget(_targetId);
        for (var i = 0; i < 10; i++) {
          await Future<void>.value();
        }
      },
    );

    // Then
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Action'))
          .controller!
          .text,
      'CreateScopeCommand',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Actor'))
          .controller!
          .text,
      _actorId,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Target'))
          .controller!
          .text,
      _targetId,
    );
  });
}
