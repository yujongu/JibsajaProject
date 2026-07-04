import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/dashboard_summary.dart';
import 'package:jibsaja/domain/entities/result.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/repositories/i_sheets_repository.dart';
import 'package:jibsaja/presentation/providers/sheets_providers.dart';

SheetTransaction _tx(String account) => SheetTransaction(
      date: DateTime(2026, 7, 1),
      account: account,
      type: TransactionType.purchase,
      amount: -1,
    );

/// Scriptable repository: [fetchResults] are returned in order; the last one
/// repeats if more fetches happen than scripted.
class _FakeRepo implements ISheetsRepository {
  _FakeRepo({this.cached, required this.fetchResults});

  final List<SheetTransaction>? cached;
  final List<Result<List<SheetTransaction>>> fetchResults;
  int fetchCount = 0;

  @override
  List<SheetTransaction>? cachedTransactions() => cached;

  @override
  Future<Result<List<SheetTransaction>>> fetchTransactions() async {
    final i = fetchCount < fetchResults.length
        ? fetchCount
        : fetchResults.length - 1;
    fetchCount++;
    return fetchResults[i];
  }

  @override
  DashboardSummary? cachedDashboard() => null;
  @override
  DateTime? cachedTransactionsAt() => null;
  @override
  DateTime? cachedDashboardAt() => null;
  @override
  Future<Result<DashboardSummary>> fetchDashboard() async =>
      const Failure('unused');
  @override
  Future<Result<void>> appendTransaction(SheetTransaction tx) async =>
      const Success(null);
}

/// Collects every AsyncValue state the provider goes through within [wait].
Future<List<AsyncValue<List<SheetTransaction>>>> _record(
  _FakeRepo repo, {
  Duration wait = const Duration(milliseconds: 100),
}) async {
  final container = ProviderContainer(overrides: [
    sheetsRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  final states = <AsyncValue<List<SheetTransaction>>>[];
  container.listen(
    transactionsProvider,
    (_, next) => states.add(next),
    fireImmediately: true,
  );
  await Future<void>.delayed(wait);
  return states;
}

void main() {
  group('transactionsProvider (cache-first stream)', () {
    test('cache + live success: cached rows first, then live, never error',
        () async {
      final states = await _record(_FakeRepo(
        cached: [_tx('CACHED')],
        fetchResults: [
          Success([_tx('LIVE')]),
        ],
      ));

      expect(states.any((s) => s.hasError), isFalse);
      final values = states.where((s) => s.hasValue).toList();
      expect(values.first.value!.single.account, 'CACHED');
      expect(values.last.value!.single.account, 'LIVE');
    });

    test('cache + failing fetch: cached rows stay, no error state, no retry',
        () async {
      final repo = _FakeRepo(
        cached: [_tx('CACHED')],
        fetchResults: [const Failure('network down')],
      );
      final states = await _record(repo);

      expect(states.any((s) => s.hasError), isFalse);
      expect(states.last.value!.single.account, 'CACHED');
      expect(repo.fetchCount, 1);
    });

    test('no cache + transient failure: retries and recovers without error',
        () async {
      final repo = _FakeRepo(
        cached: null,
        fetchResults: [
          const Failure('cold start hiccup'),
          Success([_tx('LIVE')]),
        ],
      );
      // Must outlast the 2s retry delay.
      final states =
          await _record(repo, wait: const Duration(milliseconds: 2500));

      expect(states.any((s) => s.hasError), isFalse);
      expect(states.last.value!.single.account, 'LIVE');
      expect(repo.fetchCount, 2);
    });

    test('no cache + persistent failure: error surfaces after all attempts',
        () async {
      final repo = _FakeRepo(
        cached: null,
        fetchResults: [const Failure('really down')],
      );
      final states =
          await _record(repo, wait: const Duration(milliseconds: 2500));

      expect(states.last.hasError, isTrue);
      expect(repo.fetchCount, 2);
    });
  });
}
