import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/widgets/list_filters.dart';

void main() {
  late TextEditingController name;
  late TextEditingController email;
  late int searches;
  late List<bool> toggles;

  setUp(() {
    name = TextEditingController();
    email = TextEditingController();
    searches = 0;
    toggles = <bool>[];
    addTearDown(name.dispose);
    addTearDown(email.dispose);
  });

  Future<void> pump(
    WidgetTester tester, {
    required List<ListSearchField> fields,
    bool includeDeleted = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListFilters(
          fields: fields,
          includeDeleted: includeDeleted,
          onSearch: () => searches++,
          onIncludeDeletedChanged: toggles.add,
        ),
      ),
    ),
  );

  List<ListSearchField> one() => <ListSearchField>[
    ListSearchField(controller: name, label: 'Search by name'),
  ];

  List<ListSearchField> two() => <ListSearchField>[
    ListSearchField(controller: name, label: 'Search by name'),
    ListSearchField(
      controller: email,
      label: 'Search by email',
      icon: Icons.alternate_email,
    ),
  ];

  testWidgets('GivenTheSwitch_WhenRead_ThenItIsAnnouncedAsIncludeDeleted', (
    tester,
  ) async {
    // Given
    final handle = tester.ensureSemantics();
    await pump(tester, fields: one());

    // Then
    expect(
      tester.getSemantics(find.byType(SwitchListTile)),
      isSemantics(
        label: 'Include deleted',
        hasToggledState: true,
        isToggled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('GivenTheLabel_WhenTapped_ThenTheSwitchIsToggled', (
    tester,
  ) async {
    // Given
    await pump(tester, fields: one());

    // When
    await tester.tap(find.text('Include deleted'));

    // Then
    expect(toggles, <bool>[true]);
  });

  testWidgets('GivenIncludeDeletedOn_WhenTheLabelIsTapped_ThenItTurnsOff', (
    tester,
  ) async {
    // Given
    await pump(tester, fields: one(), includeDeleted: true);

    // When
    await tester.tap(find.text('Include deleted'));

    // Then
    expect(toggles, <bool>[false]);
  });

  testWidgets('GivenOneField_WhenTheArrowIsTapped_ThenItSearches', (
    tester,
  ) async {
    // Given
    await pump(tester, fields: one());

    // When
    await tester.tap(find.byTooltip('Search'));

    // Then
    expect(searches, 1);
    expect(find.widgetWithText(FilledButton, 'Search'), findsNothing);
  });

  testWidgets('GivenOneField_WhenEnterIsPressed_ThenItSearches', (
    tester,
  ) async {
    // Given
    await pump(tester, fields: one());

    // When
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // Then
    expect(searches, 1);
  });

  testWidgets('GivenTwoFields_WhenTheButtonIsTapped_ThenItSearches', (
    tester,
  ) async {
    // Given
    await pump(tester, fields: two());

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));

    // Then
    expect(searches, 1);
    expect(find.byTooltip('Search'), findsNothing);
    expect(find.text('Search by email'), findsOneWidget);
  });

  testWidgets('GivenTwoFields_WhenEnterIsPressedInTheEmail_ThenItSearches', (
    tester,
  ) async {
    // Given
    await pump(tester, fields: two());

    // When
    await tester.tap(find.byType(TextField).last);
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // Then
    expect(searches, 1);
  });

  testWidgets('GivenAFieldController_WhenTyped_ThenTheControllerHoldsIt', (
    tester,
  ) async {
    // Given
    await pump(tester, fields: one());

    // When
    await tester.enterText(find.byType(TextField), 'abc');

    // Then
    expect(name.text, 'abc');
  });
}
