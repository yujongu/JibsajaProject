import 'sheet_account.dart';
import 'sheet_transaction.dart';
import 'transaction_category.dart';
import 'transaction_type.dart';

/// Aggregates derived from a list of [SheetTransaction], **split by currency**.
///
/// The sheet mixes currencies in one Amount column, so a single total across
/// all rows would be meaningless. Each [CurrencySummary] covers exactly one
/// currency and is internally consistent; no conversion happens anywhere (the
/// app takes no live FX feeds).
///
/// Pure Dart — no Flutter imports. This is business logic and lives in the
/// domain layer. Built via [TransactionAggregates.summarize].
class TransactionSummary {
  const TransactionSummary({
    required this.byCurrency,
    this.uncounted = const UncountedRows(),
  });

  /// One entry per currency present, most activity first. A single entry with
  /// a null [CurrencySummary.currency] means no row's currency could be
  /// resolved at all — see [TransactionAggregates.summarize].
  final List<CurrencySummary> byCurrency;

  /// Rows that would have contributed to a total but could not be placed.
  final UncountedRows uncounted;

  /// Zero-state summary for empty / not-yet-loaded data.
  static const empty = TransactionSummary(byCurrency: []);
}

/// One currency's aggregates for the period being summarized.
class CurrencySummary {
  const CurrencySummary({
    required this.currency,
    required this.totalSpending,
    required this.totalIncome,
    required this.invested,
    required this.divested,
    required this.spendingByCategory,
  });

  /// ISO code ('KRW', 'USD'), or null when no currency could be resolved and
  /// this is the single catch-all section.
  final String? currency;

  /// Total Purchase spend as a **positive magnitude**. Expense rows store
  /// negative Amounts (cash out), so this is −Σ of their amounts.
  final double totalSpending;

  /// Σ Deposit amounts — cash in, entered directly in the sheet.
  final double totalIncome;

  /// Σ Buy amounts, positive. Money put into assets, at cost.
  final double invested;

  /// Σ Sell proceeds, as a **positive magnitude** (Sell rows store negative
  /// Amounts). Kept separate from [invested] because netting them hides a month
  /// where you both bought and sold heavily behind a near-zero number.
  final double divested;

  /// Purchase spend grouped by category, sorted descending by amount. Only
  /// categories with spend above zero appear.
  final List<CategorySpending> spendingByCategory;

  /// Cash in minus cash out: positive means the month ran a surplus.
  double get netFlow => totalIncome - totalSpending;

  /// Buys minus sell proceeds — the old single "Net invested" figure.
  double get netInvested => invested - divested;

  /// How much happened in this currency at all; orders the sections so the
  /// dominant currency leads.
  double get activity => totalSpending + totalIncome + invested + divested;
}

/// Rows left out of every total, counted by reason so the UI can say what is
/// missing instead of silently under-reporting.
class UncountedRows {
  const UncountedRows({this.unknownType = 0, this.unknownCurrency = 0});

  /// Rows whose sheet `Type` the app does not recognize.
  final int unknownType;

  /// Rows whose account is absent from the sheet's `Accounts` tab (or has a
  /// blank Currency cell), so they cannot be placed under any currency.
  final int unknownCurrency;

  int get total => unknownType + unknownCurrency;
  bool get isEmpty => total == 0;
}

/// One category's share of total Purchase spending.
class CategorySpending {
  const CategorySpending({
    required this.category,
    required this.amount,
    required this.fraction,
  });

  final TransactionCategory category;

  /// Total Purchase spend for this category.
  final double amount;

  /// [amount] as a fraction (0–1) of total Purchase spending.
  /// Zero when total spending is zero.
  final double fraction;
}

/// One month's worth of transactions, for the grouped list view.
class MonthGroup {
  const MonthGroup({
    required this.year,
    required this.month,
    required this.transactions,
  });

  final int year;

  /// 1–12.
  final int month;

  /// Transactions in this month, newest first.
  final List<SheetTransaction> transactions;

  /// Stable sort key: larger = more recent.
  int get sortKey => year * 100 + month;
}

/// Running totals for one currency while [TransactionAggregates.summarize]
/// walks the rows. Private: callers only ever see the built [CurrencySummary].
class _Accumulator {
  double _spending = 0;
  double _income = 0;
  double _invested = 0;
  double _divested = 0;
  final _byCategory = <TransactionCategory, double>{};

  void add(SheetTransaction tx) {
    final amount = tx.computedAmount;
    switch (tx.type) {
      case TransactionType.purchase:
        // Expense amounts are stored negative; report spending positive.
        final spend = -amount;
        _spending += spend;
        final cat = tx.category ?? TransactionCategory.misc;
        _byCategory[cat] = (_byCategory[cat] ?? 0) + spend;
      case TransactionType.buy:
        _invested += amount; // stored positive
      case TransactionType.sell:
        _divested += -amount; // stored negative; report the magnitude
      case TransactionType.deposit:
        _income += amount; // cash in, as stored
      case TransactionType.transfer:
        break; // cash movement — neither spending, income, nor investing
      case TransactionType.unknown:
        break; // filtered out before reaching an accumulator
    }
  }

  CurrencySummary build(String? currency) {
    final spendingByCategory = [
      for (final e in _byCategory.entries)
        // A category can land on zero (a zero-amount purchase, or rows that
        // cancel out); an empty bar is noise, so it never gets a row.
        if (e.value > 0)
          CategorySpending(
            category: e.key,
            amount: e.value,
            fraction: _spending == 0 ? 0 : e.value / _spending,
          ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    return CurrencySummary(
      currency: currency,
      totalSpending: _spending,
      totalIncome: _income,
      invested: _invested,
      divested: _divested,
      spendingByCategory: spendingByCategory,
    );
  }
}

/// Pure aggregation helpers over a list of transactions. Domain logic.
extension TransactionAggregates on List<SheetTransaction> {
  /// Rows dated within the given calendar [month] (1–12) of [year].
  List<SheetTransaction> inMonth(int year, int month) =>
      where((tx) => tx.date.year == year && tx.date.month == month).toList();

  /// Summarize these rows, split by the currency of each row's account.
  ///
  /// [currencies] maps [SheetAccount.key] of an account name to its ISO code,
  /// as read from the sheet's `Accounts` tab. Rows whose account is absent from
  /// it cannot be placed under any currency, so they are left out of every
  /// total and counted in [TransactionSummary.uncounted] — with one exception:
  /// if **no** row resolves a currency (the tab is unreachable, or has not
  /// loaded yet) the result is a single catch-all section over all rows with a
  /// null currency. Returning all-zero totals in that case would look like real
  /// data rather than missing data.
  ///
  /// Empty list yields [TransactionSummary.empty].
  TransactionSummary summarize({Map<String, String> currencies = const {}}) {
    if (isEmpty) return TransactionSummary.empty;

    final buckets = <String, _Accumulator>{};
    var unknownType = 0;
    var unknownCurrency = 0;

    // Pass 1: bucket by currency. Rows with no known currency go to a holding
    // pen — whether they are reported as missing or summarized as one unlabelled
    // section depends on whether ANY row resolved a currency.
    final unplaced = <SheetTransaction>[];

    for (final tx in this) {
      if (tx.type == TransactionType.unknown) {
        unknownType++;
        continue;
      }
      final code = currencies[SheetAccount.key(tx.account)];
      if (code == null) {
        unplaced.add(tx);
        continue;
      }
      (buckets[code] ??= _Accumulator()).add(tx);
    }

    if (buckets.isEmpty) {
      // Nothing resolved: one unlabelled section over everything, and no
      // currency-related exclusions to report.
      final all = _Accumulator();
      for (final tx in unplaced) {
        all.add(tx);
      }
      return TransactionSummary(
        byCurrency: [all.build(null)],
        uncounted: UncountedRows(unknownType: unknownType),
      );
    }

    // A transfer contributes to nothing even when its currency IS known, so an
    // unplaced one is not a gap in any total — don't inflate the count with it.
    for (final tx in unplaced) {
      if (tx.type != TransactionType.transfer) unknownCurrency++;
    }

    final byCurrency = [
      for (final e in buckets.entries) e.value.build(e.key),
    ]..sort((a, b) => b.activity.compareTo(a.activity));

    return TransactionSummary(
      byCurrency: byCurrency,
      uncounted: UncountedRows(
        unknownType: unknownType,
        unknownCurrency: unknownCurrency,
      ),
    );
  }

  /// Group transactions by calendar month, newest month first and newest
  /// transaction first within each month. Empty list yields an empty list.
  List<MonthGroup> groupByMonth() {
    if (isEmpty) return const [];

    final buckets = <int, List<SheetTransaction>>{};
    for (final tx in this) {
      final key = tx.date.year * 100 + tx.date.month;
      buckets.putIfAbsent(key, () => []).add(tx);
    }

    final groups = buckets.entries.map((e) {
      final txs = [...e.value]..sort(SheetTransaction.newestFirst);
      return MonthGroup(
        year: e.key ~/ 100,
        month: e.key % 100,
        transactions: txs,
      );
    }).toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));

    return groups;
  }
}
