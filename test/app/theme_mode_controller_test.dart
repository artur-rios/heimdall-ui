import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('GivenNoStoredPreference_WhenRead_ThenModeIsSystem', () async {
    // Given
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // When
    final mode = await container.read(themeModeControllerProvider.future);

    // Then
    expect(mode, ThemeMode.system);
  });

  test('GivenModeSetToDark_WhenReadAgain_ThenDarkIsRemembered', () async {
    // Given
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeControllerProvider.future);

    // When
    await container
        .read(themeModeControllerProvider.notifier)
        .setMode(ThemeMode.dark);

    // Then
    expect(container.read(themeModeControllerProvider).value, ThemeMode.dark);
    final reread = ProviderContainer();
    addTearDown(reread.dispose);
    expect(
      await reread.read(themeModeControllerProvider.future),
      ThemeMode.dark,
    );
  });

  test('GivenUnknownStoredValue_WhenRead_ThenModeFallsBackToSystem', () async {
    // Given
    SharedPreferences.setMockInitialValues(<String, Object>{
      'heimdall.theme.mode': 'sepia',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // When
    final mode = await container.read(themeModeControllerProvider.future);

    // Then
    expect(mode, ThemeMode.system);
  });
}
