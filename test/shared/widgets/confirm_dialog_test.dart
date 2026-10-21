import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/widgets/confirm_dialog.dart';

void main() {
  Future<void> openDialog(WidgetTester tester, String expected) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTypeToConfirm(
              context: context,
              title: 'Delete',
              message: 'This cannot be undone.',
              confirmationValue: expected,
              fieldLabel: 'Name',
              confirmLabel: 'Delete forever',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool confirmEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete forever'))
      .enabled;

  testWidgets(
    'GivenAPaddedName_WhenTheTrimmedNameIsTyped_ThenConfirmIsEnabled',
    (tester) async {
      // Given
      await openDialog(tester, '  Ada Lovelace ');

      // When
      await tester.enterText(find.byType(TextField), 'Ada Lovelace');
      await tester.pump();

      // Then
      expect(confirmEnabled(tester), isTrue);
    },
  );

  testWidgets('GivenAName_WhenTypedWithPadding_ThenConfirmIsEnabled', (
    tester,
  ) async {
    // Given
    await openDialog(tester, 'Ada Lovelace');

    // When
    await tester.enterText(find.byType(TextField), ' Ada Lovelace  ');
    await tester.pump();

    // Then
    expect(confirmEnabled(tester), isTrue);
  });

  testWidgets('GivenAName_WhenADifferentTextIsTyped_ThenConfirmStaysDisabled', (
    tester,
  ) async {
    // Given
    await openDialog(tester, 'Ada Lovelace');

    // When
    await tester.enterText(find.byType(TextField), 'ada lovelace');
    await tester.pump();

    // Then
    expect(confirmEnabled(tester), isFalse);
  });

  group('showConfirm', () {
    Future<void> open(WidgetTester tester, {required bool destructive}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConfirm(
                context: context,
                title: 'Revoke',
                message: 'It stops working.',
                confirmLabel: 'Revoke it',
                destructive: destructive,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('GivenADestructiveDialog_WhenOpened_ThenCancelHasTheFocus', (
      tester,
    ) async {
      // When
      await open(tester, destructive: true);

      // Then Enter pressed by reflex cancels instead of confirming
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancel.autofocus, isTrue);
      expect(cancel.focusNode, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('GivenADestructiveDialog_WhenOpened_ThenConfirmIsRed', (
      tester,
    ) async {
      // When
      await open(tester, destructive: true);

      // Then
      final scheme = Theme.of(tester.element(find.byType(AlertDialog)))
          .colorScheme;
      final style = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Revoke it'))
          .style!;
      expect(style.backgroundColor!.resolve(<WidgetState>{}), scheme.error);
      expect(style.foregroundColor!.resolve(<WidgetState>{}), scheme.onError);
    });

    testWidgets('GivenARoutineDialog_WhenOpened_ThenItKeepsTheDefaultLook', (
      tester,
    ) async {
      // When
      await open(tester, destructive: false);

      // Then
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Revoke it'),
            )
            .style,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .autofocus,
        isFalse,
      );
    });
  });

  testWidgets('GivenADestructiveTypedDialog_WhenOpened_ThenConfirmIsRed', (
    tester,
  ) async {
    // Given
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTypeToConfirm(
              context: context,
              title: 'Delete',
              message: 'Gone.',
              confirmationValue: 'x',
              fieldLabel: 'Name',
              confirmLabel: 'Delete forever',
              destructive: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    // When
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Then
    final scheme = Theme.of(tester.element(find.byType(AlertDialog)))
        .colorScheme;
    final style = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Delete forever'),
        )
        .style!;
    expect(style.backgroundColor!.resolve(<WidgetState>{}), scheme.error);
  });
}
