import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/sheet_account.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_summary.dart';
import '../../extensions/transaction_category_ui.dart';
import '../../providers/sheets_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/money.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../shared/widgets/transaction_tile.dart';

/// The rows behind one category bar on the month summary card, plus a 12-month
/// trend for context.
///
/// Scoped to the selected month, like everything else on the Transactions page,
/// so the header total always equals the bar that opened this page. The trend
/// is the only thing here that looks outside the month, and it is read-only —
/// nothing on this page changes the month behind it.
class CategoryDetailPage extends ConsumerWidget {
  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.currency,
  });

  final TransactionCategory category;

  /// Currency of the section the tapped bar belonged to. Null means the summary
  /// resolved no currency at all and lumped every row into one section.
  final String? currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = (category: category, currency: currency);
    final txs = ref.watch(categoryTransactionsProvider(query));
    final trend = ref.watch(categoryTrendProvider(query));
    final month = ref.watch(selectedMonthProvider);
    final currencies = ref.watch(accountCurrenciesProvider);

    // Derived rather than passed in from the tapped bar, so a refresh landing
    // while this page is open updates the header instead of leaving it stale.
    final spending = _spendingFor(ref.watch(selectedMonthSummaryProvider));

    return GradientBackground(
      child: FeatureScaffold(
        title: category.label,
        loading: ref.watch(isFetchingProvider('transactionsProvider')),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.list(
                children: [
                  _Header(
                    category: category,
                    spending: spending,
                    currency: currency,
                    month: month,
                    count: txs.length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),
                  _TrendChart(
                    trend: trend,
                    category: category,
                    selectedMonth: month,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: txs.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyNotice(isDark: isDark))
                  // A sliver, not a Column: only the on-screen tiles get built,
                  // which is what keeps a heavy category scrolling smoothly.
                  : SliverList.builder(
                      itemCount: txs.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TransactionTile(
                          tx: txs[i],
                          isDark: isDark,
                          currency:
                              currencies[SheetAccount.key(txs[i].account)],
                        ),
                      ),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  /// This category's entry in the selected month's summary, or a zeroed stand-in
  /// when the month no longer has spend in it.
  CategorySpending _spendingFor(TransactionSummary summary) {
    for (final section in summary.byCurrency) {
      if (section.currency != currency) continue;
      for (final cs in section.spendingByCategory) {
        if (cs.category == category) return cs;
      }
    }
    return CategorySpending(category: category, amount: 0, fraction: 0);
  }
}

/// Total, month, transaction count and share of the month's spending.
class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.spending,
    required this.currency,
    required this.month,
    required this.count,
    required this.isDark,
  });

  final TransactionCategory category;
  final CategorySpending spending;
  final String? currency;
  final DateTime month;
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = category.color(isDark);
    final primary =
        isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final secondary =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(category.icon, size: 22, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                money(spending.amount, currency),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('MMMM yyyy').format(month)} · '
                '$count ${count == 1 ? 'transaction' : 'transactions'} · '
                '${(spending.fraction * 100).round()}% of spending',
                style: TextStyle(fontSize: 12, color: secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Twelve months of spend on this category, oldest first, ending at the
/// selected month. Read-only — the month is changed from the Transactions page.
class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.trend,
    required this.category,
    required this.selectedMonth,
    required this.isDark,
  });

  final List<MonthlySpend> trend;
  final TransactionCategory category;
  final DateTime selectedMonth;
  final bool isDark;

  static const _barHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final color = category.color(isDark);
    final trackColor =
        isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow;
    final tertiary =
        isDark ? AppColors.textTertiary : AppColors.textTertiaryLight;

    // Scale to the tallest month in the window. An all-zero window would divide
    // by zero, and every bar is empty anyway.
    final peak = trend.fold<double>(0, (a, b) => b.amount > a ? b.amount : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 12 months',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tertiary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final point in trend)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: _barHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              // An empty month keeps a hairline of track so the
                              // slot reads as "nothing here", not as missing.
                              height: peak == 0
                                  ? 2
                                  : (point.amount / peak * _barHeight)
                                      .clamp(2.0, _barHeight),
                              color: point.amount == 0
                                  ? trackColor
                                  : _isSelected(point.month)
                                      ? color
                                      : color.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM').format(point.month)[0],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _isSelected(point.month)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _isSelected(point.month) ? color : tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool _isSelected(DateTime m) =>
      m.year == selectedMonth.year && m.month == selectedMonth.month;
}

/// Only reachable if the month's rows change out from under an open page — a
/// bar exists on the card exactly when the category has spend.
class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No transactions in this category',
            style: TextStyle(
              fontSize: 13,
              color:
                  isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
}
