import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/shared/retention_window.dart';
import 'package:heimdall_ui/shared/widgets/delete_actions.dart';
import 'package:heimdall_ui/shared/widgets/failure_banner.dart';

void main() {
  var deleted = 0;
  var erased = 0;

  setUp(() {
    deleted = 0;
    erased = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool deleting = false,
    bool anonymises = false,
    bool mayDeletePermanently = true,
    String? extraWarning,
    String? blockedReason,
    Failure? failure,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeleteActions(
              noun: 'person',
              confirmationValue: 'ada@example.com',
              fieldLabel: 'Email address',
              permanentConsequence: 'Their record is erased.',
              onDelete: () async => deleted++,
              onDeletePermanently: () async => erased++,
              deleting: deleting,
              anonymises: anonymises,
              mayDeletePermanently: mayDeletePermanently,
              extraWarning: extraWarning,
              blockedReason: blockedReason,
              failure: failure,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSoft(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete person'));
    await tester.pumpAndSettle();
  }

  Future<void> openPermanent(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.pumpAndSettle();
  }

  String dialogText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .join(' ');

  testWidgets(
    'GivenTheLogicalDelete_WhenAsked_ThenItSaysOnlyAnOperatorRestores',
    (tester) async {
      // Given
      await pump(tester);

      // When
      await openSoft(tester);

      // Then the wording is what the API does, and promises no API restore
      final text = dialogText(tester);
      expect(find.text('Delete this person?'), findsOneWidget);
      expect(
        text,
        contains(
          'This hides the person. Only an operator can restore it, from the '
          'database, within the retention window.',
        ),
      );
      expect(text, isNot(contains('API can')));
      expect(text, isNot(contains('After')));
    },
  );

  testWidgets('GivenARecordThatIsAnonymised_WhenAsked_ThenTheWindowIsNamed', (
    tester,
  ) async {
    // Given
    await pump(tester, anonymises: true);

    // When
    await openSoft(tester);

    // Then
    expect(
      dialogText(tester),
      contains(
        'After $administrativeDeletionWindowText, their personal data is '
        'anonymised and cannot be restored.',
      ),
    );
    expect(administrativeDeletionWindowText, '90 days');
  });

  testWidgets('GivenAnExtraWarning_WhenAsked_ThenBothDialogsAndThePanelSayIt', (
    tester,
  ) async {
    // Given
    await pump(tester, extraWarning: 'They can sign in again.');
    expect(find.textContaining('They can sign in again.'), findsOneWidget);

    // When
    await openSoft(tester);

    // Then
    expect(dialogText(tester), contains('They can sign in again.'));

    // And
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await openPermanent(tester);
    expect(dialogText(tester), contains('They can sign in again.'));
  });

  testWidgets('GivenARecordName_WhenAsked_ThenTheDialogsNameIt', (
    tester,
  ) async {
    // Given
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeleteActions(
            noun: 'person',
            recordName: 'Ada',
            confirmationValue: 'ada@example.com',
            fieldLabel: 'Email address',
            permanentConsequence: 'Their record is erased.',
            onDelete: () async {},
            onDeletePermanently: () async {},
            deleting: false,
          ),
        ),
      ),
    );

    // When
    await openSoft(tester);

    // Then
    expect(find.text('Delete Ada?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await openPermanent(tester);
    expect(find.text('Delete Ada permanently?'), findsOneWidget);
  });

  testWidgets('GivenTheLogicalDelete_WhenConfirmed_ThenItIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await openSoft(tester);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Then
    expect((deleted, erased), (1, 0));
  });

  testWidgets('GivenTheLogicalDelete_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await openSoft(tester);

    // When
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect((deleted, erased), (0, 0));
  });

  testWidgets(
    'GivenTheLogicalDelete_WhenAsked_ThenCancelHasTheFocusAndConfirmIsRed',
    (tester) async {
      // Given
      await pump(tester);

      // When
      await openSoft(tester);

      // Then
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .autofocus,
        isTrue,
      );
      final scheme = Theme.of(tester.element(find.byType(AlertDialog)))
          .colorScheme;
      final style = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete'))
          .style!;
      expect(style.backgroundColor!.resolve(<WidgetState>{}), scheme.error);
    },
  );

  testWidgets('GivenThePermanentDelete_WhenTheValueIsTyped_ThenItIsSent', (
    tester,
  ) async {
    // Given
    await pump(tester);
    await openPermanent(tester);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Delete permanently'),
    );

    // Then it says what is erased, and stays disabled until the value matches
    final text = dialogText(tester);
    expect(find.text('Delete this person permanently?'), findsOneWidget);
    expect(
      text,
      contains(
        'Their record is erased. This cannot be undone. Type the email '
        'address to confirm:',
      ),
    );
    expect(tester.widget<FilledButton>(confirm).enabled, isFalse);

    // When
    await tester.enterText(find.byType(TextField), 'ada@example.com');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    // Then
    expect((deleted, erased), (0, 1));
  });

  testWidgets('GivenAScopeAdmin_WhenShown_ThenThereIsNoPermanentDelete', (
    tester,
  ) async {
    // When
    await pump(tester, mayDeletePermanently: false);

    // Then
    expect(find.text('Delete person'), findsOneWidget);
    expect(find.text('Delete permanently'), findsNothing);
  });

  testWidgets('GivenARequestInFlight_WhenShown_ThenBothButtonsAreDisabled', (
    tester,
  ) async {
    // When
    await pump(tester, deleting: true);

    // Then
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Delete person'),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Delete permanently'),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('GivenABlockedReason_WhenShown_ThenItReplacesTheExplanation', (
    tester,
  ) async {
    // When
    await pump(tester, blockedReason: 'You cannot delete this yourself.');

    // Then
    expect(find.text('You cannot delete this yourself.'), findsOneWidget);
    expect(find.textContaining('Deleting hides'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Delete person'),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets(
    'GivenNothingBlocking_WhenShown_ThenThePanelPromisesNoApiRestore',
    (tester) async {
      // When
      await pump(tester);

      // Then
      expect(
        find.text(
          'Deleting hides the person, and only an operator can restore it. '
          'Deleting permanently erases it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('API'), findsNothing);
    },
  );

  testWidgets('GivenARefusal_WhenShown_ThenTheApiWordsAreShown', (
    tester,
  ) async {
    // When
    await pump(
      tester,
      failure: const Failure(
        kind: FailureKind.forbidden,
        errors: <String>['Not yours to delete.'],
      ),
    );

    // Then
    expect(find.byType(ErrorBanner), findsOneWidget);
    expect(find.text('Not yours to delete.'), findsOneWidget);
  });
}
