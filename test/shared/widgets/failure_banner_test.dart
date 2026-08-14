import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/shared/widgets/failure_banner.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget banner, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? buildLightTheme(),
        home: Scaffold(body: banner),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GivenApiErrors_WhenRendered_ThenEachOneIsShown', (tester) async {
    // Given
    const failure = Failure(
      kind: FailureKind.validation,
      errors: <String>['First problem.', 'Second problem.'],
    );

    // When
    await pump(tester, const ErrorBanner(failure: failure));

    // Then
    expect(find.text('First problem.'), findsOneWidget);
    expect(find.text('Second problem.'), findsOneWidget);
  });

  testWidgets('GivenNoApiErrors_WhenRendered_ThenTheFallbackIsShown', (
    tester,
  ) async {
    // Given
    const failure = Failure(kind: FailureKind.unknown, errors: <String>[]);

    // When
    await pump(tester, const ErrorBanner(failure: failure));

    // Then
    expect(find.text('Something went wrong.'), findsOneWidget);
  });

  testWidgets('GivenARetryHandler_WhenTapped_ThenItIsCalled', (tester) async {
    // Given
    var retried = 0;

    // When
    await pump(tester, RetryBanner(onRetry: () => retried++));
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));

    // Then
    expect(retried, 1);
  });

  testWidgets('GivenNoRetryHandler_WhenRendered_ThenRetryIsDisabled', (
    tester,
  ) async {
    // Given / When
    await pump(tester, const RetryBanner(onRetry: null));

    // Then
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });

  testWidgets('GivenDarkTheme_WhenRendered_ThenTheMessageIsShown', (
    tester,
  ) async {
    // Given / When
    await pump(
      tester,
      const RetryBanner(onRetry: null),
      theme: buildDarkTheme(),
    );

    // Then
    expect(
      find.text(
        'Could not reach the API. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });
}
