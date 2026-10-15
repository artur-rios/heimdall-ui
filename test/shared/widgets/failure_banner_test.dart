import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
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

  testWidgets(
    'GivenATransportFailure_WhenRendered_ThenThePersonIsToldTheApiIsUnreachable',
    (tester) async {
      // Given
      final failure = failureFromDioException(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/scopes'),
          reason: 'Connection refused',
        ),
      );

      // When
      await pump(tester, ErrorBanner(failure: failure));

      // Then
      expect(find.text(kUnreachableMessage), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsNothing);
      expect(find.textContaining('connection errored'), findsNothing);
    },
  );

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

  // A refusal that appears without being announced is missed by anyone using
  // a screen reader.
  testWidgets('GivenAnError_WhenRendered_ThenItIsALiveRegion', (tester) async {
    // Given
    const failure = Failure(
      kind: FailureKind.validation,
      errors: <String>['First problem.'],
    );

    // When
    await pump(tester, const ErrorBanner(failure: failure));

    // Then
    expect(
      tester.getSemantics(find.text('First problem.')),
      matchesSemantics(label: 'First problem.', isLiveRegion: true),
    );
  });

  testWidgets(
    'GivenA429WithoutRetryAfter_WhenShown_ThenOnlyTheApiMessageAppears',
    (tester) async {
      // Given
      const message =
          'An email of this kind was sent to this person recently. Try again in a few minutes.';
      const failure = Failure(
        kind: FailureKind.rateLimited,
        errors: <String>[message],
      );

      // When
      await pump(tester, const ErrorBanner(failure: failure));

      // Then
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('Try again later'), findsNothing);
      expect(find.textContaining('seconds'), findsNothing);
    },
  );

  testWidgets(
    'GivenA429WithRetryAfter_WhenShown_ThenTheHintFollowsTheMessage',
    (tester) async {
      // Given
      const failure = Failure(
        kind: FailureKind.rateLimited,
        errors: <String>['Too many requests.'],
        retryAfter: Duration(seconds: 12),
      );

      // When
      await pump(tester, const ErrorBanner(failure: failure));

      // Then
      expect(find.text('Too many requests.'), findsOneWidget);
      expect(find.text('Try again in 12 seconds.'), findsOneWidget);
    },
  );
}
