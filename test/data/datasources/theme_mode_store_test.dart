import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/datasources/theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> emptyPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  group('ThemeModeStore', () {
    test('defaults to system when nothing is stored', () async {
      expect(ThemeModeStore(await emptyPrefs()).read(), ThemeMode.system);
    });

    for (final mode in ThemeMode.values) {
      test('${mode.name} round-trips through a fresh store', () async {
        final prefs = await emptyPrefs();
        ThemeModeStore(prefs).write(mode);
        expect(ThemeModeStore(prefs).read(), mode);
      });
    }

    test('an unknown stored value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'theme.mode.v1': 'neon'});
      final store = ThemeModeStore(await SharedPreferences.getInstance());
      expect(store.read(), ThemeMode.system);
    });
  });
}
