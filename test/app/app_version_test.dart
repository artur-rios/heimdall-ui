import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/app_version.dart';

void main() {
  test('GivenThePubspec_WhenItsVersionIsRead_ThenItMatchesTheAppVersion', () {
    // Given
    final pubspec = File('pubspec.yaml').readAsStringSync();

    // When
    final version = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    // Then
    expect(version, appVersion);
  });

  test(
    'GivenTheChangelog_WhenTheNewestReleaseIsRead_ThenItIsTheAppVersion',
    () {
      // Given
      final changelog = File('CHANGELOG.md').readAsStringSync();

      // When
      final newest = RegExp(
        r'^## \[([0-9]+\.[0-9]+\.[0-9]+)\]',
        multiLine: true,
      ).firstMatch(changelog)?.group(1);

      // Then
      expect(newest, appVersion);
    },
  );

  testWidgets('GivenTheFooter_WhenRendered_ThenTheVersionIsShown', (
    tester,
  ) async {
    // Given
    const footer = MaterialApp(
      home: Scaffold(bottomNavigationBar: AppVersionFooter()),
    );

    // When
    await tester.pumpWidget(footer);

    // Then
    expect(find.text('Heimdall UI v$appVersion'), findsOneWidget);
  });
}
