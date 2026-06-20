import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/sheet_transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_summary.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../../providers/sheets_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/error_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../widgets/add_transaction_sheet.dart';

/// Formats a bare number with grouping and up to 2 decimals. No currency
/// symbol — the sheet stores plain numbers and there is no currency source.
String _num(double v) => NumberFormat('#,##0.##', 'en_US').format(v);

class SheetViewPage extends ConsumerWidget {
  const SheetViewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(transactionsProvider);

    return GradientBackground(
      child: FeatureScaffold(
        title: 'Transactions',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(transactionsProvider),
          ),
        ],
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showAddTransactionSheet(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(transactionsProvider),
          child: async.when(
            loading: () => const _LoadingList(),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 80),
                ErrorCard(
                  error: e,
                  isDark: isDark,
                  onRetry: () => ref.invalidate(transactionsProvider),
                ),
              ],
            ),
            data: (txs) => txs.isEmpty
                ? _EmptyState(isDark: isDark)
                : _TransactionsList(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

/// Summary header + month-grouped transaction sections in one scroll view.
class _TransactionsList extends ConsumerWidget {
  const _TransactionsList({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(transactionSummaryProvider);
    final months = ref.watch(transactionsByMonthProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _SummaryHeader(summary: summary, isDark: isDark),
        const SizedBox(height: 20),
        for (final group in months) ...[
          _MonthHeader(group: group, isDark: isDark),
          const SizedBox(height: 8),
          for (final tx in group.transactions) ...[
            _TransactionTile(tx: tx, isDark: isDark),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// "June 2026" style section label.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.group, required this.isDark});
  final MonthGroup group;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(
      DateTime(group.year, group.month),
    );
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: isDark
              ? AppColors.textSecondary
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

/// All-time overview: total spending, net invested, and a category breakdown.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary, required this.isDark});
  final TransactionSummary summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final netIsNegative = summary.netInvested < 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Total spending',
                  value: _num(summary.totalSpending),
                  valueColor: AppColors.negative,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(
                  label: 'Net invested',
                  value: _num(summary.netInvested),
                  valueColor:
                      netIsNegative ? AppColors.warning : AppColors.positive,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (summary.spendingByCategory.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Spending by category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.textTertiaryLight,
              ),
            ),
            const SizedBox(height: 10),
            for (final cs in summary.spendingByCategory) ...[
              _CategoryBar(spending: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textTertiary
                : AppColors.textTertiaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Label + proportional bar + amount for one category's share of spending.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.spending, required this.isDark});
  final CategorySpending spending;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cat = spending.category;
    final color = cat.color;
    final trackColor =
        isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(cat.icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                cat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _num(spending.amount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, color: trackColor),
              FractionallySizedBox(
                widthFactor: spending.fraction.clamp(0.0, 1.0),
                child: Container(height: 6, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.isDark});
  final SheetTransaction tx;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(tx.type);
    final isPurchase = tx.type == TransactionType.purchase;
    final cat = tx.category;

    final title = isPurchase
        ? (tx.description.isNotEmpty
            ? tx.description
            : (cat?.label ?? 'Purchase'))
        : (tx.ticker ?? tx.type.label);

    final subtitleParts = <String>[
      tx.account,
      DateFormat('MMM d, yyyy').format(tx.date),
      if (!isPurchase && tx.quantity != null && tx.price != null)
        '${_num(tx.quantity!)} @ ${_num(tx.price!)}',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPurchase
                  ? (cat?.icon ?? Icons.shopping_bag_rounded)
                  : (tx.type == TransactionType.buy
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _num(tx.computedAmount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tx.type.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _typeColor(TransactionType t) {
  switch (t) {
    case TransactionType.purchase: return AppColors.negative;
    case TransactionType.buy:      return AppColors.primary;
    case TransactionType.sell:     return AppColors.warning;
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 16),
        for (var i = 0; i < 8; i++) ...[
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Icon(Icons.receipt_long_rounded,
            size: 48,
            color: isDark
                ? AppColors.textTertiary
                : AppColors.textTertiaryLight),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Tap Add to create your first row',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textTertiary
                  : AppColors.textTertiaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
