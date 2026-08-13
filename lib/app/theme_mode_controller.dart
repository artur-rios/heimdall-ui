import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AsyncNotifierProvider<ThemeModeController, ThemeMode>
themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

/// Remembers whether the user chose light, dark, or the system's own setting.
///
/// This is the one preference kept in `shared_preferences`: it is not sensitive,
/// and it must survive a launch. Tokens never go here.
class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const String _key = 'heimdall.theme.mode';

  @override
  Future<ThemeMode> build() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key);

    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, mode.name);
    state = AsyncData<ThemeMode>(mode);
  }
}
