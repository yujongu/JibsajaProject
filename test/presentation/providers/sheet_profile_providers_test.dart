import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/datasources/sheet_profile_store.dart';
import 'package:jibsaja/data/datasources/sheets_local_cache.dart';
import 'package:jibsaja/domain/entities/sheet_profile.dart';
import 'package:jibsaja/presentation/providers/preferences_providers.dart';
import 'package:jibsaja/presentation/providers/sheet_profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(SharedPreferences prefs) async {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('SheetProfilesNotifier.updateProfile', () {
    test('re-pointing a slot to a different URL evicts its cache', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Real slot already configured, with cached data for it.
      const original = SheetProfile(
        id: SheetProfile.realId,
        name: 'Real',
        webAppUrl: 'https://script.google.com/macros/s/OLD/exec',
        apiKey: 'k',
      );
      SheetProfileStore(prefs).writeProfile(original);
      final realCache = SheetsLocalCache(prefs, profileId: SheetProfile.realId);
      realCache.writeTransactions('{"rows": ["stale"]}');
      realCache.writeDashboard('{"grid": [["stale"]]}');

      final c = await container(prefs);
      final notifier = c.read(sheetProfilesProvider.notifier);

      notifier.updateProfile(original.copyWith(
          webAppUrl: 'https://script.google.com/macros/s/NEW/exec'));

      expect(realCache.readTransactions(), isNull,
          reason: 'stale rows from the old sheet must be dropped');
      expect(realCache.readDashboard(), isNull);
      // State reflects the new URL.
      expect(c.read(sheetProfilesProvider).real.webAppUrl,
          'https://script.google.com/macros/s/NEW/exec');
    });

    test('editing only the API key (same URL) keeps the cache', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const original = SheetProfile(
        id: SheetProfile.realId,
        name: 'Real',
        webAppUrl: 'https://script.google.com/macros/s/SAME/exec',
        apiKey: 'old-key',
      );
      SheetProfileStore(prefs).writeProfile(original);
      final realCache = SheetsLocalCache(prefs, profileId: SheetProfile.realId);
      realCache.writeTransactions('{"rows": ["keep"]}');

      final c = await container(prefs);
      c
          .read(sheetProfilesProvider.notifier)
          .updateProfile(original.copyWith(apiKey: 'new-key'));

      expect(realCache.readTransactions(), '{"rows": ["keep"]}');
      expect(c.read(sheetProfilesProvider).real.apiKey, 'new-key');
    });
  });
}
