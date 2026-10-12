import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/forms/edit_mode.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    required bool editing,
    bool mayEdit = true,
    bool saving = false,
    bool canSave = false,
  }) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => EditableSection(
              title: 'Details',
              editing: editing,
              mayEdit: mayEdit,
              saving: saving,
              canSave: canSave,
              onEdit: () => calls.add('edit'),
              onCancel: () => calls.add('cancel'),
              onSave: () => calls.add('save'),
              child: TextField(
                readOnly: !editing,
                decoration: recordFieldDecoration(
                  context,
                  label: 'Name',
                  editing: editing,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return calls;
  }

  testWidgets('GivenViewMode_WhenRendered_ThenOnlyEditIsOffered', (
    tester,
  ) async {
    // Given
    final calls = await pump(tester, editing: false);

    // When
    await tester.tap(find.text('Edit'));

    // Then
    expect(calls, <String>['edit']);
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('GivenARecordTheCallerMayNotChange_WhenRendered_ThenNoEdit', (
    tester,
  ) async {
    // Given
    await pump(tester, editing: false, mayEdit: false);

    // Then
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('GivenEditModeWithNoChange_WhenRendered_ThenSaveIsExplained', (
    tester,
  ) async {
    // Given
    await pump(tester, editing: true);

    // Then
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save changes'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('No changes to save yet.'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('GivenEditModeWithAChange_WhenSaved_ThenSaveIsCalled', (
    tester,
  ) async {
    // Given
    final calls = await pump(tester, editing: true, canSave: true);

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));

    // Then
    expect(calls, <String>['save', 'cancel']);
    expect(find.text('No changes to save yet.'), findsNothing);
  });

  testWidgets('GivenASaveInFlight_WhenRendered_ThenBothControlsWait', (
    tester,
  ) async {
    // Given
    await pump(tester, editing: true, saving: true, canSave: true);

    // Then
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancel'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenViewMode_WhenAFieldIsDecorated_ThenItHasNoCounter', (
    tester,
  ) async {
    // Given
    await pump(tester, editing: false);

    // When
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;

    // Then
    expect(decoration.counterText, '');
    expect(decoration.filled, isTrue);
  });
}
