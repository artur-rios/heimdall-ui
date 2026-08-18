import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/shared/widgets/adaptive_collection.dart';

/// A minimal item, so the widget's own behavior is what is under test rather
/// than any one feature's entity.
class _Row {
  const _Row(this.name, this.state);

  final String name;
  final String state;
}

const List<_Row> _rows = <_Row>[
  _Row('Acme', 'Active'),
  _Row('Globex', 'Deleted'),
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    List<_Row> items = _rows,
    int pageNumber = 1,
    int totalPages = 1,
    bool busy = false,
    bool reservesFloatingAction = false,
    void Function(_Row item)? onTap,
    ValueChanged<int>? onPageChanged,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? buildLightTheme(),
        home: Scaffold(
          body: AdaptiveCollection<_Row>(
            items: items,
            busy: busy,
            reservesFloatingAction: reservesFloatingAction,
            pageNumber: pageNumber,
            totalPages: totalPages,
            totalItems: items.length,
            onPageChanged: onPageChanged ?? (_) {},
            onTap: onTap,
            title: (item) => item.name,
            subtitle: (item) => 'subtitle',
            columns: <CollectionColumn<_Row>>[
              CollectionColumn<_Row>(
                label: 'State',
                cell: (item) => Text(item.state),
              ),
              CollectionColumn<_Row>(
                label: 'Table only',
                onCard: false,
                cell: (item) => const Text('table-only'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // FR-UX-04 — one declaration, two renderings.
  testWidgets('GivenACompactWindow_WhenRendered_ThenCardsAreUsed', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('GivenAnExpandedWindow_WhenRendered_ThenATableIsUsed', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('GivenATableOnlyColumn_WhenCardsAreUsed_ThenItIsOmitted', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(400, 900));

    // Then
    expect(find.text('table-only'), findsNothing);
  });

  testWidgets('GivenATableOnlyColumn_WhenATableIsUsed_ThenItIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900));

    // Then
    expect(find.text('table-only'), findsNWidgets(2));
  });

  testWidgets('GivenACard_WhenTapped_ThenTheItemIsReported', (tester) async {
    // Given
    _Row? tapped;
    await pump(
      tester,
      size: const Size(400, 900),
      onTap: (item) => tapped = item,
    );

    // When
    await tester.tap(find.text('Globex'));
    await tester.pumpAndSettle();

    // Then
    expect(tapped?.name, 'Globex');
  });

  testWidgets('GivenTheLastPage_WhenRendered_ThenNextIsDisabled', (
    tester,
  ) async {
    // Given / When
    await pump(
      tester,
      size: const Size(1400, 900),
      pageNumber: 3,
      totalPages: 3,
    );

    // Then
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.chevron_right),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenAPageInFlight_WhenRendered_ThenPagingIsDisabled', (
    tester,
  ) async {
    // Given / When
    await pump(
      tester,
      size: const Size(1400, 900),
      pageNumber: 2,
      totalPages: 3,
      busy: true,
    );

    // Then
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.chevron_right),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('GivenAMiddlePage_WhenNextTapped_ThenTheNextPageIsReported', (
    tester,
  ) async {
    // Given
    int? requested;
    await pump(
      tester,
      size: const Size(1400, 900),
      pageNumber: 2,
      totalPages: 5,
      onPageChanged: (page) => requested = page,
    );

    // When
    await tester.tap(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();

    // Then
    expect(requested, 3);
  });

  // The pager and a floating action button share the bottom-right corner, and
  // the button is drawn on top.
  testWidgets('GivenAFloatingAction_WhenRendered_ThenThePagerIsClearOfIt', (
    tester,
  ) async {
    // Given / When
    await pump(
      tester,
      size: const Size(1400, 900),
      reservesFloatingAction: true,
    );

    // Then
    expect(
      tester.getBottomRight(find.byIcon(Icons.chevron_right)).dy,
      lessThan(900 - 72),
    );
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheItemsAreStillShown', (
    tester,
  ) async {
    // Given / When
    await pump(tester, size: const Size(1400, 900), theme: buildDarkTheme());

    // Then
    expect(find.text('Acme'), findsOneWidget);
  });
}
