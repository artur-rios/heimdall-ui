import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';

void main() {
  test('GivenLightTheme_WhenBuilt_ThenUsesMaterialThreeAndLightBrightness', () {
    // Given / When
    final theme = buildLightTheme();

    // Then
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  test('GivenDarkTheme_WhenBuilt_ThenUsesMaterialThreeAndDarkBrightness', () {
    // Given / When
    final theme = buildDarkTheme();

    // Then
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });

  test('GivenBothThemes_WhenCompared_ThenTheyDifferInTheirSurfaces', () {
    // Given
    final light = buildLightTheme();
    final dark = buildDarkTheme();

    // When
    final differ = light.colorScheme.surface != dark.colorScheme.surface;

    // Then
    expect(differ, isTrue);
  });
}
