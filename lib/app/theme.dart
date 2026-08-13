import 'package:flutter/material.dart';

/// Heimdall guards the bridge; the palette starts from its watchful blue.
///
/// Both schemes derive from this one seed, so a color is never defined twice
/// and no screen can hard-code something that survives a theme change.
const Color heimdallSeedColor = Color(0xFF1B5E9C);

ThemeData _themeFor(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: heimdallSeedColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}

ThemeData buildLightTheme() => _themeFor(Brightness.light);

ThemeData buildDarkTheme() => _themeFor(Brightness.dark);
