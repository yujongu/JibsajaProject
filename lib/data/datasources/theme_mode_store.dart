import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's appearance choice so a pinned Light/Dark survives
/// restarts. Unset means "follow the OS", which is what the app did before
/// the setting existed.
class ThemeModeStore {
  const ThemeModeStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'theme.mode.v1';

  /// Defaults to [ThemeMode.system]; an unknown stored value (from a future
  /// schema change) also falls back to it.
  ThemeMode read() => switch (_prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void write(ThemeMode mode) {
    _prefs.setString(_key, mode.name);
  }
}
