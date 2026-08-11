import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibsaja/domain/entities/dashboard_summary.dart';
import 'package:jibsaja/domain/entities/result.dart';
import 'package:jibsaja/domain/entities/sheet_account.dart';
import 'package:jibsaja/domain/entities/sheet_holding.dart';
import 'package:jibsaja/domain/entities/sheet_transaction.dart';
import 'package:jibsaja/domain/entities/transaction_category.dart';
import 'package:jibsaja/domain/entities/transaction_type.dart';
import 'package:jibsaja/domain/repositories/i_sheets_repository.dart';
import 'package:jibsaja/presentation/providers/sheets_providers.dart';

SheetTransaction _tx(
  String account, {
  DateTime? date,
  double amount = -1,
  TransactionCategory? category,
  int rowIndex = 0,
}) =>
    SheetTransaction(
      date: date ?? DateTime(2026, 7, 1),
      account: account,
      type: TransactionType.purchase,
      category: category,
      amount: amount,
      rowIndex: rowIndex,
    );

/// Scriptable repository: [fetchResults] are returned in order; the last one
/// repeats if more fetches happen than scripted.
class _FakeRepo implements ISheetsRepository {
  _FakeRepo({
    this.cached,
    required this.fetchResults,
    this.accountsResult = const Failure('unused'),
    this.accountsAt,
    this.holdingsResult = const Failure('unused'),
    this.holdingsAt,
  });

  final List<SheetTransaction>? cached;
  final List<Result<List<SheetTransaction>>> fetchResults;
  final Result<List<SheetAccount>> accountsResult;
  final DateTime? accountsAt;
  final Result<List<SheetHolding>> holdingsResult;
  final DateTime? holdingsAt;
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
  DateTime? cachedAccountsAt() => accountsAt;
  @override
  Future<Result<DashboardSummary>> fetchDashboard() async =>
      const Failure('unused');
  @override
  List<SheetAccount>? cachedAccounts() => null;
  @override
  Future<Result<List<SheetAccount>>> fetchAccounts() async => accountsResult;
  @override
  List<SheetHolding>? cachedHoldings() => null;
  @override
  DateTime? cachedHoldingsAt() => holdingsAt;
  @override
  Future<Result<List<SheetHolding>>> fetchHoldings() async => holdingsResult;
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
      expect(container.read(selectedMonthSummaryProvider).byCurrency, isEmpty);
      // Still navigable in both directions — never a dead end.
      final nav = container.read(monthNavProvider);
      expect(nav.canGoBack, isTrue);
      expect(nav.canGoForward, isTrue);
    });

    test('summary and rows follow the selected month into the past', () async {
      final container = await loaded(sample());

      // Current month first. No accounts are configured on the fake repo, so
      // the summary falls back to a single unlabelled section.
      expect(
          container.read(selectedMonthSummaryProvider).byCurrency.single
              .totalSpending,
          100);
      expect(container.read(selectedMonthTransactionsProvider).single.account,
          'NOW');

      container.read(selectedMonthProvider.notifier).shift(-2);

      expect(
          container.read(selectedMonthSummaryProvider).byCurrency.single
              .totalSpending,
          50);
      expect(container.read(selectedMonthTransactionsProvider).single.account,
          'OLD');
    });
  });

  group('accountCurrenciesProvider', () {
    Future<ProviderContainer> loaded(Result<List<SheetAccount>> accounts) async {
      final container = ProviderContainer(overrides: [
        sheetsRepositoryProvider.overrideWithValue(_FakeRepo(
          fetchResults: [const Success(<SheetTransaction>[])],
          accountsResult: accounts,
        )),
      ]);
      addTearDown(container.dispose);
      container.listen(accountsProvider, (_, _) {}, fireImmediately: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container;
    }

    test('maps account names case- and whitespace-insensitively', () async {
      final container = await loaded(const Success([
        SheetAccount(name: '  BoA ', currency: 'USD'),
        SheetAccount(name: '토스증권 국내 주식', currency: 'KRW'),
      ]));

      final currencies = container.read(accountCurrenciesProvider);
      expect(currencies['boa'], 'USD');
      expect(currencies['토스증권 국내 주식'], 'KRW');
    });

    test('an account with a blank currency is left out', () async {
      final container = await loaded(const Success([
        SheetAccount(name: 'Mystery', currency: ''),
      ]));

      expect(container.read(accountCurrenciesProvider), isEmpty);
    });

    test('a failed accounts fetch degrades to an empty map', () async {
      final container = await loaded(const Failure('Accounts tab missing'));

      expect(container.read(accountCurrenciesProvider), isEmpty);
    });
  });

  group('accountsUpdatedAtProvider', () {
    Future<ProviderContainer> loaded({DateTime? at}) async {
      final container = ProviderContainer(overrides: [
        sheetsRepositoryProvider.overrideWithValue(_FakeRepo(
          fetchResults: [const Success(<SheetTransaction>[])],
          accountsResult: const Success(<SheetAccount>[]),
          accountsAt: at,
        )),
      ]);
      addTearDown(container.dispose);
      container.listen(accountsProvider, (_, _) {}, fireImmediately: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container;
    }

    test('surfaces when the cached accounts were fetched', () async {
      final at = DateTime(2026, 8, 7, 9, 30);
      final container = await loaded(at: at);

      expect(container.read(accountsUpdatedAtProvider), at);
    });

    test('is null before any successful fetch has ever landed', () async {
      // Also the state of an install whose cached accounts body predates the
      // timestamp key — the label then hides rather than inventing a time.
      final container = await loaded();

      expect(container.read(accountsUpdatedAtProvider), isNull);
    });
  });

  group('holdings', () {
    const nvda = SheetHolding(
      symbol: 'NVDA',
      currency: 'USD',
      baseValue: 2368,
      marketValue: 3802,
      unrealizedGain: 1434,
    );
    const tsla = SheetHolding(
      symbol: 'TSLA',
      currency: 'USD',
      baseValue: 4797,
      marketValue: 3915,
      unrealizedGain: -882,
    );
    const samsung = SheetHolding(
      symbol: '삼성전자',
      currency: 'KRW',
      baseValue: 8208000,
      marketValue: 8916000,
      unrealizedGain: 708000,
    );

    Future<ProviderContainer> loaded(
      Result<List<SheetHolding>> result, {
      DateTime? at,
      Duration wait = const Duration(milliseconds: 50),
    }) async {
      final container = ProviderContainer(overrides: [
        sheetsRepositoryProvider.overrideWithValue(_FakeRepo(
          fetchResults: [const Success(<SheetTransaction>[])],
          holdingsResult: result,
          holdingsAt: at,
        )),
      ]);
      addTearDown(container.dispose);
      container.listen(holdingsProvider, (_, _) {}, fireImmediately: true);
      await Future<void>.delayed(wait);
      return container;
    }

    test('sections split by currency, largest first', () async {
      final container = await loaded(const Success([nvda, samsung, tsla]));

      final sections = container.read(holdingsSectionsProvider);
      expect(sections.map((s) => s.currency), ['KRW', 'USD']);
      expect(sections.last.marketValue, 3802 + 3915);
    });

    test('a failed fetch surfaces as an error, unlike accounts', () async {
      // The Accounts tab degrades to an empty list because it only supplies
      // currency labels elsewhere. This tab IS the page, so "the sheet is
      // unreachable" must not render as "you own nothing".
      //
      // The wait must clear the cold-start retry — with no cache, the stream
      // makes _coldStartAttempts tries 2s apart before the error surfaces.
      final container = await loaded(
        const Failure('Holdings tab not found'),
        wait: const Duration(milliseconds: 2500),
      );

      expect(container.read(holdingsProvider).hasError, isTrue);
      expect(container.read(holdingsSectionsProvider), isEmpty);
    });

    test('surfaces when the cached holdings were fetched', () async {
      final at = DateTime(2026, 8, 11, 9, 30);
      final container = await loaded(const Success(<SheetHolding>[]), at: at);

      expect(container.read(holdingsUpdatedAtProvider), at);
    });

    test('is null before any successful fetch has ever landed', () async {
      final container = await loaded(const Success(<SheetHolding>[]));

      expect(container.read(holdingsUpdatedAtProvider), isNull);
    });

    test('opens on largest position first', () async {
      final container = await loaded(const Success([nvda, tsla]));

      expect(container.read(holdingOrderProvider),
          (field: HoldingSort.value, dir: SortDir.desc));
      expect(
        container.read(holdingsSectionsProvider).single.holdings
            .map((h) => h.symbol),
        ['TSLA', 'NVDA'],
      );
    });

    test('tapping the active column reverses it', () async {
      final container = await loaded(const Success([nvda, tsla]));
      final order = container.read(holdingOrderProvider.notifier);

      order.tap(HoldingSort.value);

      expect(container.read(holdingOrderProvider).dir, SortDir.asc);
      expect(
        container.read(holdingsSectionsProvider).single.holdings
            .map((h) => h.symbol),
        ['NVDA', 'TSLA'],
      );

      // And back again.
      order.tap(HoldingSort.value);
      expect(container.read(holdingOrderProvider).dir, SortDir.desc);
    });

    test('tapping a different column takes that column\'s natural direction',
        () async {
      final container = await loaded(const Success([nvda, tsla]));
      final order = container.read(holdingOrderProvider.notifier);

      // Reverse Value first, so the carried-over direction would be visible.
      order.tap(HoldingSort.value);
      order.tap(HoldingSort.gain);

      expect(container.read(holdingOrderProvider),
          (field: HoldingSort.gain, dir: SortDir.desc));

      // A name column starts A→Z, not biggest-first.
      order.tap(HoldingSort.symbol);
      expect(container.read(holdingOrderProvider),
          (field: HoldingSort.symbol, dir: SortDir.asc));
    });
  });

  group('category drill-down', () {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    Future<ProviderContainer> loaded(List<SheetTransaction> txs) async {
      final container = ProviderContainer(overrides: [
        sheetsRepositoryProvider.overrideWithValue(
          _FakeRepo(
            cached: txs,
            fetchResults: [Success(txs)],
            accountsResult: const Success(
              [SheetAccount(name: 'BoA', currency: 'KRW')],
            ),
          ),
        ),
      ]);
      addTearDown(container.dispose);
      await container.read(transactionsProvider.future);
      // accountCurrenciesProvider reads accountsProvider, which needs a listener
      // before it emits.
      container.listen(accountsProvider, (_, _) {}, fireImmediately: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container;
    }

    test('categoryTransactionsProvider returns only that category, this month',
        () async {
      final container = await loaded([
        _tx('BoA',
            date: thisMonth,
            amount: -10,
            category: TransactionCategory.food,
            rowIndex: 1),
        _tx('BoA',
            date: thisMonth,
            amount: -20,
            category: TransactionCategory.travel,
            rowIndex: 2),
        // Right category, wrong month.
        _tx('BoA',
            date: lastMonth,
            amount: -30,
            category: TransactionCategory.food,
            rowIndex: 3),
      ]);

      final rows = container.read(categoryTransactionsProvider(
        (category: TransactionCategory.food, currency: 'KRW'),
      ));

      expect(rows.map((t) => t.rowIndex), [1]);
    });

    test('categoryTrendProvider looks outside the selected month', () async {
      final container = await loaded([
        _tx('BoA',
            date: thisMonth, amount: -10, category: TransactionCategory.food),
        _tx('BoA',
            date: lastMonth, amount: -30, category: TransactionCategory.food),
      ]);

      final trend = container.read(categoryTrendProvider(
        (category: TransactionCategory.food, currency: 'KRW'),
      ));

      // The month list is scoped to one month; the trend deliberately is not.
      expect(trend, hasLength(12));
      expect(trend.last.amount, 10);
      expect(trend[10].amount, 30);
    });

    test('the trend window follows the selected month', () async {
      final container = await loaded([
        _tx('BoA',
            date: lastMonth, amount: -30, category: TransactionCategory.food),
      ]);
      container.read(selectedMonthProvider.notifier).shift(-1);

      final trend = container.read(categoryTrendProvider(
        (category: TransactionCategory.food, currency: 'KRW'),
      ));

      expect(trend.last.month, lastMonth);
      expect(trend.last.amount, 30);
    });
  });
}
