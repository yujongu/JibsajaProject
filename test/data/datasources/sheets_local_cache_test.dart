import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/data/datasources/sheets_local_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SheetsLocalCache profile namespacing', () {
    test('two caches with different profileIds do not collide', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final testCache = SheetsLocalCache(prefs, profileId: 'test');
      final realCache = SheetsLocalCache(prefs, profileId: 'real');

      testCache.writeTransactions('{"rows": ["from-test"]}');
      realCache.writeTransactions('{"rows": ["from-real"]}');
      testCache.writeDashboard('{"grid": [["test"]]}');

      expect(testCache.readTransactions(), '{"rows": ["from-test"]}');
      expect(realCache.readTransactions(), '{"rows": ["from-real"]}');
      expect(testCache.readDashboard(), '{"grid": [["test"]]}');
      expect(realCache.readDashboard(), isNull);
      expect(realCache.dashboardTimestamp(), isNull);
      expect(testCache.transactionsTimestamp(), isNotNull);

      // The keys themselves carry the profile id.
      expect(prefs.getString('cache.transactions.body.test.v1'), isNotNull);
      expect(prefs.getString('cache.transactions.body.real.v1'), isNotNull);
    });

    test('same profileId shares the cache', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      SheetsLocalCache(prefs, profileId: 'real').writeTransactions('body');
      expect(SheetsLocalCache(prefs, profileId: 'real').readTransactions(),
          'body');
    });

    test('evict drops this profile\'s bodies + timestamps only', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final real = SheetsLocalCache(prefs, profileId: 'real');
      final test = SheetsLocalCache(prefs, profileId: 'test');
      real.writeTransactions('{"rows": []}');
      real.writeDashboard('{"grid": []}');
      real.writeAccounts('{"grid": []}');
      test.writeTransactions('{"rows": []}');

      real.evict();

      expect(real.readTransactions(), isNull);
      expect(real.readDashboard(), isNull);
      expect(real.readAccounts(), isNull);
      expect(real.transactionsTimestamp(), isNull);
      expect(real.dashboardTimestamp(), isNull);
      // The other slot is untouched.
      expect(test.readTransactions(), isNotNull);
    });

    test('accounts round-trip and stay namespaced by profile', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final real = SheetsLocalCache(prefs, profileId: 'real');
      final test = SheetsLocalCache(prefs, profileId: 'test');

      real.writeAccounts('{"grid": [["Account Name","Currency"]]}');

      expect(real.readAccounts(), '{"grid": [["Account Name","Currency"]]}');
      expect(test.readAccounts(), isNull);
      expect(prefs.getString('cache.accounts.body.real.v1'), isNotNull);
    });
  });
}
