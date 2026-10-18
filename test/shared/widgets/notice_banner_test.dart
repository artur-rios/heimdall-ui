import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/shared/widgets/notice_banner.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: NoticeBanner(message: 'Invitation sent')),
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
}
