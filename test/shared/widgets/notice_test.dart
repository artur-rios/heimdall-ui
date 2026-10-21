import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/shared/widgets/notice.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Notice('Invitation sent')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GivenAMessage_WhenRendered_ThenItIsShown', (tester) async {
    // Given
    final theme = buildLightTheme();

    // When
    await pump(tester, theme);

    // Then
    expect(find.text('Invitation sent'), findsOneWidget);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheMessageIsStillShown', (
    tester,
  ) async {
    // Given
    final theme = buildDarkTheme();

    // When
    await pump(tester, theme);

    // Then
    expect(find.text('Invitation sent'), findsOneWidget);
  });

  testWidgets('GivenANotice_WhenRendered_ThenItIsALiveRegion', (tester) async {
    // Given
    final handle = tester.ensureSemantics();

    // When
    await pump(tester, buildLightTheme());

    // Then a screen reader announces it when it appears
    final semantics = tester.getSemantics(
      find.ancestor(
        of: find.text('Invitation sent'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
    );
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('GivenAnErrorNotice_WhenRendered_ThenItUsesTheErrorColours', (
    tester,
  ) async {
    // Given
    final theme = buildLightTheme();

    // When
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Notice('Deleted', isError: true, icon: Icons.delete_outline),
        ),
      ),
    );

    // Then
    final box = tester.widget<Container>(find.byType(Container).first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, theme.colorScheme.errorContainer);
    expect(
      tester.widget<Icon>(find.byType(Icon)).color,
      theme.colorScheme.onErrorContainer,
    );
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('GivenAPlainNotice_WhenRendered_ThenItConfirmsInQuietColours', (
    tester,
  ) async {
    // Given
    final theme = buildLightTheme();

    // When
    await pump(tester, theme);

    // Then
    final box = tester.widget<Container>(find.byType(Container).first);
    expect(
      (box.decoration! as BoxDecoration).color,
      theme.colorScheme.secondaryContainer,
    );
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
