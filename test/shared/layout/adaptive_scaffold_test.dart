import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/home/presentation/destinations.dart';
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

  // #144 — a System Admin's six destinations on a short window, or with the
  // soft keyboard open, are more than the rail's height; the rail scrolls
  // rather than overflowing, so the last one stays reachable.
  for (final (:name, :size, :keyboard)
      in <({String name, Size size, double keyboard})>[
        (name: 'AShortWindow', size: const Size(640, 360), keyboard: 0),
        (name: 'TheKeyboardOpen', size: const Size(900, 800), keyboard: 380),
      ]) {
    testWidgets(
      'Given${name}AndSixDestinations_WhenRendered_ThenTheRailFitsAndHealthCanBeTapped',
      (tester) async {
        // Given
        final systemAdmin = destinationsFor(
          const Principal(id: 'p', email: '', role: Role.systemAdmin),
        );
        expect(systemAdmin, hasLength(6));
        expect(systemAdmin.last.label, 'Health');
        var selected = -1;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);

        // When
        final errors = await _errorsDuring(() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildLightTheme(),
              home: AdaptiveScaffold(
                destinations: systemAdmin,
                selectedIndex: 0,
                onDestinationSelected: (index) => selected = index,
                title: const Text('Heimdall'),
                body: const Text('content'),
              ),
            ),
          );
          await tester.pumpAndSettle();
        });

        // Then
        expect(errors, isEmpty);
        final health = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Health'),
        );
        await tester.ensureVisible(health);
        await tester.pumpAndSettle();
        expect(health.hitTestable(), findsOneWidget);
        await tester.tap(health);
        expect(selected, 5);
      },
    );
  }
}

/// Runs [body] and returns what it reported to [FlutterError.onError], such
/// as a `RenderFlex` overflow.
Future<List<FlutterErrorDetails>> _errorsDuring(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final reportError = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = reportError;
  }

  return errors;
}
