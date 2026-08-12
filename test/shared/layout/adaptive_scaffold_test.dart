import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/shared/layout/adaptive_scaffold.dart';
import 'package:heimdall_ui/shared/layout/destination.dart';

void main() {
  const destinations = <AppDestination>[
    AppDestination(label: 'Scopes', icon: Icons.domain, route: '/scopes'),
    AppDestination(label: 'Persons', icon: Icons.people, route: '/persons'),
  ];

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    ValueChanged<int>? onDestinationSelected,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? buildLightTheme(),
        home: AdaptiveScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          title: const Text('Heimdall'),
          body: const Text('content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GivenCompactWidth_WhenRendered_ThenShowsBottomNavigation', (
    tester,
  ) async {
    // Given / When
    await pumpAt(tester, const Size(400, 800));

    // Then
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('GivenMediumWidth_WhenRendered_ThenShowsCollapsedRail', (
    tester,
  ) async {
    // Given / When
    await pumpAt(tester, const Size(800, 800));

    // Then
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('GivenExpandedWidth_WhenRendered_ThenShowsExtendedRail', (
    tester,
  ) async {
    // Given / When
    await pumpAt(tester, const Size(1400, 900));

    // Then
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets(
    'GivenCompactWidth_WhenDestinationTapped_ThenSelectionIsReported',
    (tester) async {
      // Given
      var selected = -1;
      await pumpAt(
        tester,
        const Size(400, 800),
        onDestinationSelected: (index) => selected = index,
      );

      // When
      await tester.tap(find.text('Persons'));
      await tester.pumpAndSettle();

      // Then
      expect(selected, 1);
    },
  );

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheShellStillRenders', (
    tester,
  ) async {
    // Given / When
    await pumpAt(tester, const Size(1400, 900), theme: buildDarkTheme());

    // Then
    expect(find.text('content'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
