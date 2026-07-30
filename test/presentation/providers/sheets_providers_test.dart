import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/dashboard_summary.dart';
import 'package:jibsaja/domain/entities/result.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/repositories/i_sheets_repository.dart';
import 'package:jibsaja/presentation/providers/sheets_providers.dart';

SheetTransaction _tx(
  String account, {
  DateTime? date,
  double amount = -1,
}) =>
    SheetTransaction(
      date: date ?? DateTime(2026, 7, 1),
      account: account,
      type: TransactionType.purchase,
      amount: amount,
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

  group('selectedMonthProvider', () {
    test('defaults to the current month, normalized to the 1st', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final now = DateTime.now();
      expect(container.read(selectedMonthProvider),
          DateTime(now.year, now.month));
    });

    test('shifting back from January lands on December of the previous year',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedMonthProvider.notifier);

      notifier.select(DateTime(2026, 1, 15));
      notifier.shift(-1);

      expect(container.read(selectedMonthProvider), DateTime(2025, 12));
    });

    test('shifting forward from December lands on January of the next year',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedMonthProvider.notifier);

      notifier.select(DateTime(2026, 12, 31));
      notifier.shift(1);

      expect(container.read(selectedMonthProvider), DateTime(2027, 1));
    });
  });

  group('month navigation + selected-month aggregates', () {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final twoMonthsAgo = DateTime(now.year, now.month - 2);

    /// Container whose transactions have already emitted, so the derived
    /// providers can be read synchronously.
    Future<ProviderContainer> loaded(List<SheetTransaction> txs) async {
      final container = ProviderContainer(overrides: [
        sheetsRepositoryProvider.overrideWithValue(
          _FakeRepo(cached: txs, fetchResults: [Success(txs)]),
        ),
      ]);
      addTearDown(container.dispose);
      await container.read(transactionsProvider.future);
      return container;
    }

    List<SheetTransaction> sample() => [
          _tx('NOW', date: thisMonth, amount: -100),
          _tx('OLD', date: twoMonthsAgo, amount: -50),
        ];

    test('bounds span the oldest row month through the current month',
        () async {
      final container = await loaded(sample());

      expect(container.read(monthBoundsProvider),
          (oldest: twoMonthsAgo, newest: thisMonth));
    });

    test('bounds are null with no rows', () async {
      final container = await loaded([]);

      expect(container.read(monthBoundsProvider), isNull);
      final nav = container.read(monthNavProvider);
      expect(nav.canGoBack, isFalse);
      expect(nav.canGoForward, isFalse);
    });

    test('cannot go forward past the current month', () async {
      final container = await loaded(sample());

      final nav = container.read(monthNavProvider);
      expect(nav.canGoForward, isFalse);
      expect(nav.canGoBack, isTrue);
    });

    test('cannot go back past the oldest month with rows', () async {
      final container = await loaded(sample());
      container.read(selectedMonthProvider.notifier).shift(-2);

      final nav = container.read(monthNavProvider);
      expect(nav.canGoBack, isFalse);
      expect(nav.canGoForward, isTrue);
    });

    test('a gap month between bounds is reachable and reads empty', () async {
      final container = await loaded(sample());
      container.read(selectedMonthProvider.notifier).shift(-1);

      expect(container.read(selectedMonthTransactionsProvider), isEmpty);
      expect(container.read(selectedMonthSummaryProvider).totalSpending, 0);
      // Still navigable in both directions — never a dead end.
      final nav = container.read(monthNavProvider);
      expect(nav.canGoBack, isTrue);
      expect(nav.canGoForward, isTrue);
    });

    test('summary and rows follow the selected month into the past', () async {
      final container = await loaded(sample());

      // Current month first.
      expect(container.read(selectedMonthSummaryProvider).totalSpending, 100);
      expect(container.read(selectedMonthTransactionsProvider).single.account,
          'NOW');

      container.read(selectedMonthProvider.notifier).shift(-2);

      expect(container.read(selectedMonthSummaryProvider).totalSpending, 50);
      expect(container.read(selectedMonthTransactionsProvider).single.account,
          'OLD');
    });
  });
}
