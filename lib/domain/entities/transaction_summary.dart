import 'sheet_transaction.dart';
import 'transaction_category.dart';
import 'transaction_type.dart';

/// All-time aggregates derived from a list of [SheetTransaction].
///
/// Pure Dart — no Flutter imports. This is business logic and lives in the
/// domain layer. Built via [TransactionAggregates.summarize].
class TransactionSummary {
  const TransactionSummary({
    required this.totalSpending,
    required this.netInvested,
    required this.spendingByCategory,
  });

  /// Total Purchase spend as a **positive magnitude**. Expense rows store
  /// negative Amounts (cash out), so this is −Σ of their amounts.
  final double totalSpending;

  /// Σ signed trade amounts. Buy rows are positive, Sell rows negative
  /// (the sheet's sign convention), so this is buys minus sell proceeds.
  final double netInvested;

  /// Purchase spend grouped by category, sorted descending by amount.
  final List<CategorySpending> spendingByCategory;

  /// Zero-state summary for empty / not-yet-loaded data.
  static const empty = TransactionSummary(
    totalSpending: 0,
    netInvested: 0,
    spendingByCategory: [],
  );
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

/// Pure aggregation helpers over a list of transactions. Domain logic.
extension TransactionAggregates on List<SheetTransaction> {
  /// Rows dated within the given calendar [month] (1–12) of [year].
  List<SheetTransaction> inMonth(int year, int month) =>
      where((tx) => tx.date.year == year && tx.date.month == month).toList();

  /// Compute the all-time summary. Empty list yields [TransactionSummary.empty].
  TransactionSummary summarize() {
    if (isEmpty) return TransactionSummary.empty;

    var totalSpending = 0.0;
    var netInvested = 0.0;
    final byCategory = <TransactionCategory, double>{};

    for (final tx in this) {
      final amount = tx.computedAmount;
      switch (tx.type) {
        case TransactionType.purchase:
          // Expense amounts are stored negative; report spending positive.
          final spend = -amount;
          totalSpending += spend;
          final cat = tx.category ?? TransactionCategory.misc;
          byCategory[cat] = (byCategory[cat] ?? 0) + spend;
        case TransactionType.buy:
        case TransactionType.sell:
          netInvested += amount; // signed: Buy +, Sell −
        case TransactionType.transfer:
          break; // cash leg of a trade — neither spending nor investing
      }
    }

    final spendingByCategory = byCategory.entries
        .map(
          (e) => CategorySpending(
            category: e.key,
            amount: e.value,
            fraction: totalSpending == 0 ? 0 : e.value / totalSpending,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final cappedByCategory = _capCategories(spendingByCategory, totalSpending);

    return TransactionSummary(
      totalSpending: totalSpending,
      netInvested: netInvested,
      spendingByCategory: cappedByCategory,
    );
  }

  /// Cap the breakdown at the top 4 categories plus a single trailing "Other"
  /// that folds in the remaining tail. With 5 or fewer categories, returns the
  /// list unchanged. If [TransactionCategory.misc] is already in the top 4,
  /// the folded tail is merged into it rather than producing a second "Other".
  /// [sorted] must already be sorted descending by amount.
  static List<CategorySpending> _capCategories(
    List<CategorySpending> sorted,
    double totalSpending,
  ) {
    if (sorted.length <= 5) return sorted;

    final top = sorted.take(4).toList();
    final tail = sorted.skip(4);

    var tailAmount = 0.0;
    var tailFraction = 0.0;
    for (final cs in tail) {
      tailAmount += cs.amount;
      tailFraction += cs.fraction;
    }

    final existingOtherIndex =
        top.indexWhere((cs) => cs.category == TransactionCategory.misc);

    if (existingOtherIndex != -1) {
      final existing = top[existingOtherIndex];
      top[existingOtherIndex] = CategorySpending(
        category: TransactionCategory.misc,
        amount: existing.amount + tailAmount,
        fraction: existing.fraction + tailFraction,
      );
      return top;
    }

    return [
      ...top,
      CategorySpending(
        category: TransactionCategory.misc,
        amount: tailAmount,
        fraction: totalSpending == 0 ? 0 : tailAmount / totalSpending,
      ),
    ];
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
