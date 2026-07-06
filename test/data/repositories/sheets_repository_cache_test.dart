import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jibsaja/data/datasources/sheets_local_cache.dart';
import 'package:jibsaja/data/repositories/sheets_repository_impl.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rowsBody =
      '{"rows": [{"Date": "2026-07-01", "Account": "Toss", "Type": "Expense", '
      '"Category": "Food", "Description": "lunch", "Symbol": "", '
      '"Quantity": "", "Price": "", "Amount": 12000}]}';

  const gridBody = '{"grid": [["Total", 1000]]}';

  // The endpoint is injected now (runtime sheet switching); any non-empty
  // https URL exercises the configured path against the mock client.
  const url = 'https://example.com/exec';

  Future<SheetsLocalCache> emptyCache() async {
    SharedPreferences.setMockInitialValues({});
    return SheetsLocalCache(await SharedPreferences.getInstance(),
        profileId: 'test');
  }

  group('cachedTransactions', () {
    test('returns null when nothing has been cached', () async {
      final repo = SheetsRepositoryImpl(webAppUrl: url, cache: await emptyCache());
      expect(repo.cachedTransactions(), isNull);
      expect(repo.cachedDashboard(), isNull);
      expect(repo.cachedTransactionsAt(), isNull);
      expect(repo.cachedDashboardAt(), isNull);
    });

    test('returns null when no cache is wired at all', () {
      const repo = SheetsRepositoryImpl(webAppUrl: url);
      expect(repo.cachedTransactions(), isNull);
      expect(repo.cachedDashboard(), isNull);
    });

    test('a successful fetch persists rows that a fresh read parses back',
        () async {
      final cache = await emptyCache();
      final repo = SheetsRepositoryImpl(
        webAppUrl: url,
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
        webAppUrl: url,
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
      final repo = SheetsRepositoryImpl(webAppUrl: url, cache: cache);
      expect(repo.cachedTransactions(), isNull);
    });
  });

  group('injected endpoint', () {
    test('an empty webAppUrl fails every remote call without touching http',
        () async {
      final repo = SheetsRepositoryImpl(
        webAppUrl: '',
        client: MockClient((_) async => fail('must not be called')),
      );

      expect((await repo.fetchTransactions()).isFailure, isTrue);
      expect((await repo.fetchDashboard()).isFailure, isTrue);
      final append = await repo.appendTransaction(SheetTransaction(
        date: DateTime(2026, 7, 1),
        account: 'Toss',
        type: TransactionType.purchase,
        amount: 10,
      ));
      expect(append.isFailure, isTrue);
    });

    test('requests go to the injected URL with the injected apiKey', () async {
      Uri? seen;
      final repo = SheetsRepositoryImpl(
        webAppUrl: url,
        apiKey: 'sekret',
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(rowsBody, 200);
        }),
      );

      expect((await repo.fetchTransactions()).isSuccess, isTrue);
      expect(seen, isNotNull);
      expect(seen!.host, 'example.com');
      expect(seen!.queryParameters['apiKey'], 'sekret');
    });
  });

  group('cachedDashboard', () {
    test('a successful fetch persists the grid for a fresh read', () async {
      final cache = await emptyCache();
      final repo = SheetsRepositoryImpl(
        webAppUrl: url,
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
        webAppUrl: url,
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
