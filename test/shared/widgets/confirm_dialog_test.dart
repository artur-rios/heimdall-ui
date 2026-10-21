import 'package:flutter/material.dart';
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
}
