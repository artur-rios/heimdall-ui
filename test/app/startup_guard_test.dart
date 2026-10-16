import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/startup_guard.dart';
import 'package:heimdall_ui/core/config/app_config.dart';

void main() {
  // A release build that refuses its API must say so on screen, not leave a
  // blank window with the reason only in a log nobody reads.
  testWidgets('GivenACleartextReleaseApi_WhenStarted_ThenTheReasonIsShown', (
    tester,
  ) async {
    // Given
    const config = AppConfig(apiBaseUrl: 'http://heimdall.example.com');
    final logged = <String>[];

    // When
    final root = guardStartup(
      config,
      () => const MaterialApp(home: Text('the app')),
      release: true,
      web: false,
      log: logged.add,
    );
    await tester.pumpWidget(root);

    // Then
    expect(find.text('the app'), findsNothing);
    expect(find.text('Heimdall cannot start'), findsOneWidget);
    expect(
      find.textContaining('HEIMDALL_API_BASE_URL', findRichText: true),
      findsOneWidget,
    );
    expect(logged, hasLength(1));
    expect(logged.single, contains('http://heimdall.example.com'));
  });

  testWidgets('GivenAnHttpsReleaseApi_WhenStarted_ThenTheAppIsShown', (
    tester,
  ) async {
    // Given
    const config = AppConfig(apiBaseUrl: 'https://heimdall.example.com');
    final logged = <String>[];

    // When
    final root = guardStartup(
      config,
      () => const MaterialApp(home: Text('the app')),
      release: true,
      web: false,
      log: logged.add,
    );
    await tester.pumpWidget(root);

    // Then
    expect(find.text('the app'), findsOneWidget);
    expect(logged, isEmpty);
  });
}
