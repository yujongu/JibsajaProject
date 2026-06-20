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

  /// Sum of `computedAmount` for every Purchase row.
  final double totalSpending;

  /// (Σ Buy computedAmount) − (Σ Sell computedAmount).
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
  /// Compute the all-time summary. Empty list yields [TransactionSummary.empty].
  TransactionSummary summarize() {
    if (isEmpty) return TransactionSummary.empty;

    var totalSpending = 0.0;
    var buyTotal = 0.0;
    var sellTotal = 0.0;
    final byCategory = <TransactionCategory, double>{};

    for (final tx in this) {
      final amount = tx.computedAmount;
      switch (tx.type) {
        case TransactionType.purchase:
          totalSpending += amount;
          final cat = tx.category ?? TransactionCategory.other;
          byCategory[cat] = (byCategory[cat] ?? 0) + amount;
        case TransactionType.buy:
          buyTotal += amount;
        case TransactionType.sell:
          sellTotal += amount;
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
      netInvested: buyTotal - sellTotal,
      spendingByCategory: cappedByCategory,
    );
  }

  /// Cap the breakdown at the top 4 categories plus a single trailing "Other"
  /// that folds in the remaining tail. With 5 or fewer categories, returns the
  /// list unchanged. If [TransactionCategory.other] is already in the top 4,
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
        top.indexWhere((cs) => cs.category == TransactionCategory.other);

    if (existingOtherIndex != -1) {
      final existing = top[existingOtherIndex];
      top[existingOtherIndex] = CategorySpending(
        category: TransactionCategory.other,
        amount: existing.amount + tailAmount,
        fraction: existing.fraction + tailFraction,
      );
      return top;
    }

    return [
      ...top,
      CategorySpending(
        category: TransactionCategory.other,
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
      final txs = [...e.value]..sort((a, b) => b.date.compareTo(a.date));
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
