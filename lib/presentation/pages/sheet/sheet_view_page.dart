import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/sheet_transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../../providers/sheets_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/error_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../widgets/add_transaction_sheet.dart';

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
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: txs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _TransactionTile(tx: txs[i], isDark: isDark),
                  ),
          ),
        ),
      ),
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

  static String _num(double v) =>
      NumberFormat('#,##0.##', 'en_US').format(v);
}

Color _typeColor(TransactionType t) {
  switch (t) {
    case TransactionType.purchase: return AppColors.negative;
    case TransactionType.buy:      return AppColors.primary;
    case TransactionType.sell:     return const Color(0xFFF59E0B);
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
