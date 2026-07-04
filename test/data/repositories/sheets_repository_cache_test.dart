import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jibsaja/data/datasources/sheets_local_cache.dart';
import 'package:jibsaja/data/repositories/sheets_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rowsBody =
      '{"rows": [{"Date": "2026-07-01", "Account": "Toss", "Type": "Expense", '
      '"Category": "Food", "Description": "lunch", "Symbol": "", '
      '"Quantity": "", "Price": "", "Amount": 12000}]}';

  const gridBody = '{"grid": [["Total", 1000]]}';

  Future<SheetsLocalCache> emptyCache() async {
    SharedPreferences.setMockInitialValues({});
    return SheetsLocalCache(await SharedPreferences.getInstance());
  }

  group('cachedTransactions', () {
    test('returns null when nothing has been cached', () async {
      final repo = SheetsRepositoryImpl(cache: await emptyCache());
      expect(repo.cachedTransactions(), isNull);
      expect(repo.cachedDashboard(), isNull);
      expect(repo.cachedTransactionsAt(), isNull);
      expect(repo.cachedDashboardAt(), isNull);
    });

    test('returns null when no cache is wired at all', () {
      const repo = SheetsRepositoryImpl();
      expect(repo.cachedTransactions(), isNull);
      expect(repo.cachedDashboard(), isNull);
    });

    test('a successful fetch persists rows that a fresh read parses back',
        () async {
      final cache = await emptyCache();
      final repo = SheetsRepositoryImpl(
        cache: cache,
        client: MockClient((_) async => http.Response(rowsBody, 200)),
      );

      final live = await repo.fetchTransactions();
      expect(live.isSuccess, isTrue);

      final cached = repo.cachedTransactions();
      expect(cached, isNotNull);
      expect(cached, hasLength(1));
      expect(cached!.single.account, 'Toss');
      expect(cached.single.amount, 12000);

      final at = repo.cachedTransactionsAt();
      expect(at, isNotNull);
      expect(DateTime.now().difference(at!).inSeconds, lessThan(5));
    });

    test('a failed fetch does not overwrite the cached rows', () async {
      final cache = await emptyCache();
      cache.writeTransactions(rowsBody);
      final repo = SheetsRepositoryImpl(
        cache: cache,
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      final live = await repo.fetchTransactions();
      expect(live.isFailure, isTrue);
      expect(repo.cachedTransactions(), hasLength(1));
    });

    test('a corrupt cached body reads back as null, not a crash', () async {
      final cache = await emptyCache();
      cache.writeTransactions('{not json');
      final repo = SheetsRepositoryImpl(cache: cache);
      expect(repo.cachedTransactions(), isNull);
    });
  });

  group('cachedDashboard', () {
    test('a successful fetch persists the grid for a fresh read', () async {
      final cache = await emptyCache();
      final repo = SheetsRepositoryImpl(
        cache: cache,
        client: MockClient((_) async => http.Response(gridBody, 200)),
      );

      final live = await repo.fetchDashboard();
      expect(live.isSuccess, isTrue);
      expect(repo.cachedDashboard(), isNotNull);
    });

    test('an error payload is not cached', () async {
      final cache = await emptyCache();
      final repo = SheetsRepositoryImpl(
        cache: cache,
        client: MockClient(
            (_) async => http.Response(jsonEncode({'error': 'nope'}), 200)),
      );

      final live = await repo.fetchDashboard();
      expect(live.isFailure, isTrue);
      expect(repo.cachedDashboard(), isNull);
      expect(repo.cachedDashboardAt(), isNull);
    });
  });
}
