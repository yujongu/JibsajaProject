import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/datasources/theme_mode_store.dart';
import 'package:jibsaja/presentation/providers/preferences_providers.dart';
import 'package:jibsaja/presentation/providers/theme_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(SharedPreferences prefs) {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('ThemeModeNotifier', () {
    test('starts on system when nothing was ever picked', () async {
      SharedPreferences.setMockInitialValues({});
      final c = container(await SharedPreferences.getInstance());
      expect(c.read(themeModeProvider), ThemeMode.system);
    });

    test('seeds its initial state from the store', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ThemeModeStore(prefs).write(ThemeMode.light);

      expect(container(prefs).read(themeModeProvider), ThemeMode.light);
    });

    test('set updates state and persists for the next launch', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = container(prefs);

      c.read(themeModeProvider.notifier).set(ThemeMode.dark);

      expect(c.read(themeModeProvider), ThemeMode.dark);
      // A fresh container over the same prefs comes up dark.
      expect(container(prefs).read(themeModeProvider), ThemeMode.dark);
    });
  });
}
