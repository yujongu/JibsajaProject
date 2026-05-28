import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/firestore_error_card.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/transactions/transaction_form_sheet.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final selectedMonth = ref.watch(selectedMonthProvider);
    final txsAsync = ref.watch(transactionsStreamProvider);
    final monthlyTxs = ref.watch(monthlyTransactionsProvider);
    final income = ref.watch(monthlyIncomeProvider);
    final expenses = ref.watch(monthlyExpensesProvider);
    final net = income - expenses;
    final categoryExpenses = ref.watch(categoryExpensesProvider);
    final dailyExpenses = ref.watch(dailyExpensesProvider);

    return FeatureScaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: 0,
          left: 20,
          right: 20,
          bottom: 120,
        ),
        children: [
          Row(
            children: [
              Text('Transactions', style: textTheme.headlineLarge),
              const Spacer(),
              GlassIconButton(
                icon: Icons.add_rounded,
                onPressed: () => showTransactionFormSheet(context),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your spending and income',
            style: textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 24),

          // Monthly summary
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MonthStat(label: 'Income', value: _fmt(income), color: AppColors.positive, isDark: isDark),
                Container(width: 1, height: 40, color: isDark ? AppColors.darkDivider : AppColors.lightBorder),
                _MonthStat(label: 'Expenses', value: _fmt(expenses), color: AppColors.negative, isDark: isDark),
                Container(width: 1, height: 40, color: isDark ? AppColors.darkDivider : AppColors.lightBorder),
                _MonthStat(label: 'Net', value: _fmt(net), color: net >= 0 ? AppColors.positive : AppColors.negative, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Month selector
          _MonthSelector(
            month: selectedMonth,
            isDark: isDark,
            onPrev: () => ref.read(selectedMonthProvider.notifier).state =
                DateTime(selectedMonth.year, selectedMonth.month - 1),
            onNext: () {
              final next = DateTime(selectedMonth.year, selectedMonth.month + 1);
              if (!next.isAfter(DateTime.now())) {
                ref.read(selectedMonthProvider.notifier).state = next;
              }
            },
          ),
          const SizedBox(height: 24),

          Text(DateFormat('MMMM yyyy').format(selectedMonth), style: textTheme.headlineSmall),
          const SizedBox(height: 12),

          if (dailyExpenses.isNotEmpty) ...[
            _DailySpendingChart(
              dailyExpenses: dailyExpenses,
              selectedMonth: selectedMonth,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ],

          if (categoryExpenses.isNotEmpty) ...[
            _CategoryBreakdown(
              categoryExpenses: categoryExpenses,
              totalExpenses: expenses,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            Text('All Transactions', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
          ],

          if (txsAsync.hasError)
            FirestoreErrorCard(error: txsAsync.error!, isDark: isDark)
          else if (txsAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: LinearProgressIndicator(),
            )
          else if (monthlyTxs.isEmpty)
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40,
                      color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
                  const SizedBox(height: 12),
                  Text('No transactions yet', style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Tap + to record a transaction',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                      )),
                  const SizedBox(height: 20),
                  GlassButton(label: 'Add Transaction', icon: Icons.add_rounded,
                      onPressed: () => showTransactionFormSheet(context)),
                ],
              ),
            )
          else
            Column(
              children: monthlyTxs
                  .map((tx) => _TransactionTile(tx: tx, isDark: isDark))
                  .toList(),
            ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    final sign = v < 0 ? '-' : '';
    return '$sign₩${NumberFormat('#,###').format(v.abs().toInt())}';
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.tx, required this.isDark});
  final Transaction tx;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = tx.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.positive : AppColors.negative;
    final amountPrefix = isIncome ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(tx.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.negative.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 22),
        ),
        confirmDismiss: (_) => showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: Text('Delete "${tx.title}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.negative),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
        onDismissed: (_) async {
          final user = ref.read(authStateProvider).valueOrNull;
          if (user == null) return;
          try {
            await ref.read(transactionRepositoryProvider).deleteTransaction(user.uid, tx.id);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
            }
          }
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showTransactionFormSheet(context, existing: tx),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tx.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tx.category.icon, size: 18, color: tx.category.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                          )),
                      Text(
                        '${tx.category.label} · ${DateFormat('MMM d').format(tx.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$amountPrefix₩${NumberFormat('#,###').format(tx.amount.toInt())}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.categoryExpenses,
    required this.totalExpenses,
    required this.isDark,
  });

  final Map<TransactionCategory, double> categoryExpenses;
  final double totalExpenses;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spending by Category', style: textTheme.headlineSmall),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: categoryExpenses.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value.key;
              final amount = entry.value.value;
              final percent = totalExpenses > 0 ? amount / totalExpenses : 0.0;
              final isLast = index == categoryExpenses.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(category.icon, size: 16, color: category.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                category.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₩${NumberFormat('#,###').format(amount.toInt())}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                  ),
                                ),
                                Text(
                                  '${(percent * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? AppColors.darkDivider
                                : AppColors.surfaceContainerLow,
                            valueColor: AlwaysStoppedAnimation<Color>(category.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.darkDivider : AppColors.surfaceContainerLow,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DailySpendingChart extends StatelessWidget {
  const _DailySpendingChart({
    required this.dailyExpenses,
    required this.selectedMonth,
    required this.isDark,
  });

  final Map<int, double> dailyExpenses;
  final DateTime selectedMonth;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final daysInMonth = DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
    final maxVal = dailyExpenses.values.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxVal == 0) return const SizedBox.shrink();

    final barColor = AppColors.negative;
    final dimColor = isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow;

    final groups = List.generate(daysInMonth, (i) {
      final day = i + 1;
      final amount = dailyExpenses[day] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: amount,
            color: amount > 0 ? barColor : dimColor,
            width: 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    });

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Spending', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.2,
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal * 0.5,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? AppColors.darkDivider : AppColors.surfaceContainerLow,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 4,
                      getTitlesWidget: (value, _) {
                        final day = value.toInt() + 1;
                        if (day % 5 != 0 && day != 1) return const SizedBox.shrink();
                        return Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppColors.darkCard : AppColors.surfaceCard,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tooltipMargin: 4,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = group.x + 1;
                      return BarTooltipItem(
                        'Day $day\n₩${NumberFormat('#,###').format(rod.toY.toInt())}',
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({required this.label, required this.value, required this.color, required this.isDark});
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(label, style: textTheme.labelMedium?.copyWith(
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
        const SizedBox(height: 4),
        Text(value, style: textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.isDark, required this.onPrev, required this.onNext});
  final DateTime month;
  final bool isDark;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCurrentMonth = month.year == DateTime.now().year && month.month == DateTime.now().month;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GlassIconButton(icon: Icons.chevron_left_rounded, onPressed: onPrev, size: 36, iconSize: 20),
          const Spacer(),
          Text(DateFormat('MMMM yyyy').format(month), style: textTheme.titleMedium),
          const Spacer(),
          GlassIconButton(
            icon: Icons.chevron_right_rounded,
            onPressed: isCurrentMonth ? null : onNext,
            size: 36,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
