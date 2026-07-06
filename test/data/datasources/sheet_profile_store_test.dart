import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/core/config/app_config.dart';
import 'package:jibsaja/data/datasources/sheet_profile_store.dart';
import 'package:jibsaja/domain/entities/sheet_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> emptyPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  group('SheetProfileStore', () {
    test('first read of the Test slot seeds it from AppConfig and persists',
        () async {
      final prefs = await emptyPrefs();
      final store = SheetProfileStore(prefs);

      final seeded = store.read(SheetProfile.testId);
      expect(seeded.webAppUrl, AppConfig.sheetsWebAppUrl);
      expect(seeded.apiKey, AppConfig.sheetsApiKey);
      expect(seeded.name, 'Test');

      // Persisted, not just returned: a fresh store over the same prefs
      // reads the same values back.
      expect(prefs.getString('profiles.test.url.v1'),
          AppConfig.sheetsWebAppUrl);
      expect(SheetProfileStore(prefs).read(SheetProfile.testId), seeded);
    });

    test('an empty stored Test URL re-seeds from AppConfig when available',
        () async {
      // Simulates a first run that seeded from an *empty* AppConfig (or any
      // way the stored URL ended up blank): a later read must recover the
      // now-available config instead of staying blank forever.
      SharedPreferences.setMockInitialValues({
        'profiles.test.url.v1': '',
        'profiles.test.key.v1': '',
      });
      final prefs = await SharedPreferences.getInstance();

      final reseeded = SheetProfileStore(prefs).read(SheetProfile.testId);
      expect(reseeded.webAppUrl, AppConfig.sheetsWebAppUrl);
      expect(reseeded.apiKey, AppConfig.sheetsApiKey);
      // Persisted, so it survives the next launch.
      expect(prefs.getString('profiles.test.url.v1'),
          AppConfig.sheetsWebAppUrl);
    });

    test('a non-empty stored Test URL is never overwritten by the seed',
        () async {
      SharedPreferences.setMockInitialValues({
        'profiles.test.url.v1': 'https://script.google.com/macros/s/MINE/exec',
        'profiles.test.key.v1': 'mine',
      });
      final prefs = await SharedPreferences.getInstance();
      final read = SheetProfileStore(prefs).read(SheetProfile.testId);
      expect(read.webAppUrl, 'https://script.google.com/macros/s/MINE/exec');
      expect(read.apiKey, 'mine');
    });

    test('the Real slot defaults to empty (not configured), never seeded',
        () async {
      final store = SheetProfileStore(await emptyPrefs());
      final real = store.read(SheetProfile.realId);
      expect(real.webAppUrl, isEmpty);
      expect(real.apiKey, isEmpty);
      expect(real.name, 'Real');
      expect(real.isConfigured, isFalse);
    });

    test('writeProfile round-trips through a fresh store', () async {
      final prefs = await emptyPrefs();
      const edited = SheetProfile(
        id: SheetProfile.realId,
        name: 'Real',
        webAppUrl: 'https://script.google.com/macros/s/REAL/exec',
        apiKey: 'real-key',
      );

      SheetProfileStore(prefs).writeProfile(edited);
      expect(SheetProfileStore(prefs).read(SheetProfile.realId), edited);
    });

    test('active id defaults to test', () async {
      final store = SheetProfileStore(await emptyPrefs());
      expect(store.activeId(), SheetProfile.testId);
    });

    test('setActive persists across store instances', () async {
      final prefs = await emptyPrefs();
      SheetProfileStore(prefs).setActive(SheetProfile.realId);
      expect(SheetProfileStore(prefs).activeId(), SheetProfile.realId);
    });

    test('an unknown stored active id falls back to test', () async {
      SharedPreferences.setMockInitialValues(
          {'profiles.active.v1': 'staging'});
      final store = SheetProfileStore(await SharedPreferences.getInstance());
      expect(store.activeId(), SheetProfile.testId);
    });
  });
}
