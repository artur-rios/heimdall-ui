import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart' as envelope;
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/erasure_request_repository.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';
import 'package:heimdall_ui/features/erasure_requests/presentation/reconciliation_dialog.dart';
import 'package:heimdall_ui/shared/widgets/failure_banner.dart';
import 'package:mocktail/mocktail.dart';

class _MockErasureRequestRepository extends Mock
    implements ErasureRequestRepository {}

const _a = '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c';
const _b = '7a2d3c0f-1e5b-4d2f-8b4c-3a7e9f8b2c1d';

void main() {
  late _MockErasureRequestRepository repository;

  Future<void> open(WidgetTester tester, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          erasureRequestRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: theme ?? buildLightTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showReconciliationDialog(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder dialogReapply() => find.widgetWithText(FilledButton, 'Re-apply');

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  /// Submits the paste and reaches the confirmation.
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(dialogReapply());
    await tester.pumpAndSettle();
  }

  Finder confirmReapply() => find.descendant(
    of: find.byType(AlertDialog).last,
    matching: find.widgetWithText(FilledButton, 'Re-apply'),
  );

  setUp(() {
    repository = _MockErasureRequestRepository();
    when(
      () => repository.list(
        overdueOnly: any(named: 'overdueOnly'),
        pageNumber: any(named: 'pageNumber'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Success<envelope.Page<OutstandingErasure>>(
        envelope.Page<OutstandingErasure>(
          items: <OutstandingErasure>[],
          pageNumber: 1,
          pageSize: 20,
          totalItems: 0,
          totalPages: 1,
        ),
      ),
    );
  });

  testWidgets('GivenTheDialog_WhenOpened_ThenTheRunbookStepIsExplained', (
    tester,
  ) async {
    // When
    await open(tester);

    // Then
    expect(
      find.textContaining(
        'Paste the identifiers the anonymisation pass logged since the '
        'backup was taken.',
      ),
      findsOneWidget,
    );
  });

  // AF-32e
  testWidgets('GivenAnEmptyPaste_WhenSubmitted_ThenItIsRefused', (
    tester,
  ) async {
    // Given
    await open(tester);

    // When
    await submit(tester);

    // Then
    expect(find.text('Paste at least one identifier.'), findsOneWidget);
    verifyNever(() => repository.reapply(any()));
  });

  // AF-32d
  testWidgets('GivenInvalidEntries_WhenSubmitted_ThenTheyAreListed', (
    tester,
  ) async {
    // Given
    await open(tester);
    await paste(tester, '$_a not-an-id');

    // When
    await submit(tester);

    // Then
    expect(find.text('These are not identifiers: not-an-id'), findsOneWidget);
    verifyNever(() => repository.reapply(any()));
  });

  testWidgets('GivenIds_WhenSubmitted_ThenItAsksOnceMore', (tester) async {
    // Given
    await open(tester);
    await paste(tester, '$_a, ${_a.toUpperCase()}');

    // When
    await submit(tester);

    // Then
    expect(find.text('Re-apply erasure to 1 identifier?'), findsOneWidget);
    verifyNever(() => repository.reapply(any()));
  });

  testWidgets('GivenSeveralIds_WhenSubmitted_ThenTheCountIsPlural', (
    tester,
  ) async {
    // Given
    await open(tester);
    await paste(tester, '$_a\n$_b');

    // When
    await submit(tester);

    // Then
    expect(find.text('Re-apply erasure to 2 identifiers?'), findsOneWidget);
  });

  // AF-32f
  testWidgets(
    'GivenTheConfirmation_WhenCancelled_ThenNothingIsSentAndThePasteIsKept',
    (tester) async {
      // Given
      await open(tester);
      await paste(tester, _a);
      await submit(tester);

      // When
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      // Then
      verifyNever(() => repository.reapply(any()));
      expect(find.text(_a), findsOneWidget);
    },
  );

  testWidgets('GivenTheConfirmation_WhenConfirmed_ThenTheOutcomeIsShown', (
    tester,
  ) async {
    // Given
    when(() => repository.reapply(<String>[_a, _b])).thenAnswer(
      (_) async => const Success<ReconciliationOutcome>(
        ReconciliationOutcome(
          anonymised: 1,
          alreadyAnonymised: 0,
          notFound: <String>[_b],
        ),
      ),
    );
    await open(tester);
    await paste(tester, '$_a\n$_b');
    await submit(tester);

    // When
    await tester.tap(confirmReapply());
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Anonymised: 1'), findsOneWidget);
    expect(find.text('Already anonymised: 0'), findsOneWidget);
    expect(find.text('Not found: 1'), findsOneWidget);
    expect(find.text(_b), findsOneWidget);
    expect(
      find.text('Not found is the ordinary case for most of the ledger.'),
      findsOneWidget,
    );
  });

  // AF-32g
  testWidgets(
    'GivenARefusal_WhenConfirmed_ThenApiErrorsAreShownAndThePasteIsKept',
    (tester) async {
      // Given
      when(() => repository.reapply(any())).thenAnswer(
        (_) async => const FailureResult<ReconciliationOutcome>(
          Failure(
            kind: FailureKind.validation,
            errors: <String>['At least one subject identifier is required.'],
          ),
        ),
      );
      await open(tester);
      await paste(tester, _a);
      await submit(tester);

      // When
      await tester.tap(confirmReapply());
      await tester.pumpAndSettle();

      // Then
      expect(
        find.text('At least one subject identifier is required.'),
        findsOneWidget,
      );
      expect(find.text(_a), findsOneWidget);
    },
  );

  // AF-32h
  testWidgets(
    'GivenATransportFailure_WhenConfirmed_ThenTheBannerAndPasteStay',
    (tester) async {
      // Given
      when(() => repository.reapply(any())).thenAnswer(
        (_) async => const FailureResult<ReconciliationOutcome>(
          Failure(kind: FailureKind.network, errors: <String>[]),
        ),
      );
      await open(tester);
      await paste(tester, _a);
      await submit(tester);

      // When
      await tester.tap(confirmReapply());
      await tester.pumpAndSettle();

      // Then
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text(_a), findsOneWidget);
    },
  );

  testWidgets(
    'GivenARunInFlight_WhenDismissed_ThenTheDialogStaysAndRefreshes',
    (tester) async {
      // Given
      final pending = Completer<Result<ReconciliationOutcome>>();
      when(() => repository.reapply(any())).thenAnswer((_) => pending.future);
      await open(tester);
      await paste(tester, _a);
      await submit(tester);
      await tester.tap(confirmReapply());
      await tester.pumpAndSettle();

      // When
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      // Then
      expect(cancel.onPressed, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);

      pending.complete(
        const Success<ReconciliationOutcome>(
          ReconciliationOutcome(
            anonymised: 1,
            alreadyAnonymised: 0,
            notFound: <String>[],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anonymised: 1'), findsOneWidget);
      verify(() => repository.list(overdueOnly: false, pageNumber: 1))
          .called(1);
    },
  );

  testWidgets('GivenTheDarkTheme_WhenOpened_ThenItRenders', (tester) async {
    // When
    await open(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Re-apply erasures'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
