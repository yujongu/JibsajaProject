import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/holding.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/holding_type_ui.dart';
import '../../providers/transaction_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/form_sheet_widgets.dart';
import '../transactions/transaction_form_sheet.dart';

Future<void> showHoldingDetailSheet(
  BuildContext context,
  Holding holding, {
  bool hasLivePrice = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HoldingDetailSheet(
      holding: holding,
      hasLivePrice: hasLivePrice,
    ),
  );
}

class HoldingDetailSheet extends ConsumerWidget {
  const HoldingDetailSheet({
    super.key,
    required this.holding,
    this.hasLivePrice = false,
  });

  final Holding holding;
  final bool hasLivePrice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final allTxs = ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
    final trades = allTxs
        .where((t) =>
            t.type.isTrade && t.ticker?.toUpperCase() == holding.ticker.toUpperCase())
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final isPositive = holding.gainLoss >= 0;
    final gainColor = isPositive ? AppColors.positive : AppColors.negative;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetDragHandle(isDark: isDark),
            const SizedBox(height: 20),

            // ── Header ───────────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: holding.type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(holding.type.icon, size: 22, color: holding.type.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        holding.ticker,
                        style: textTheme.titleLarge,
                      ),
                      if (hasLivePrice) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.positive.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.positive,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ]),
                    Text(
                      holding.name,
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Portfolio Value Card ──────────────────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Market Value',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(holding.totalValue, holding.currency),
                              style: textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: gainColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: gainColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${isPositive ? '+' : ''}${holding.gainLossPercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: gainColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: _StatCell(
                        label: 'Qty',
                        value: NumberFormat('#,##0.####', 'en_US').format(holding.quantity),
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Avg Cost',
                        value: CurrencyFormatter.format(holding.avgCostPrice, holding.currency),
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Price Now',
                        value: CurrencyFormatter.format(holding.currentPrice, holding.currency),
                        isDark: isDark,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: gainColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Text(
                        'Unrealized P&L',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${isPositive ? '+' : ''}${CurrencyFormatter.format(holding.gainLoss, holding.currency)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: gainColor,
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Trade History ─────────────────────────────────────────────────
            Row(children: [
              Text('Trade History', style: textTheme.titleMedium),
              const Spacer(),
              Builder(
                builder: (ctx) => TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showTransactionFormSheet(
                      ctx,
                      initialType: TransactionType.buy,
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Trade'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            if (trades.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No trades recorded for ${holding.ticker}',
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              )
            else
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: trades.asMap().entries.map((entry) {
                    final tx = entry.value;
                    final isLast = entry.key == trades.length - 1;
                    return Column(
                      children: [
                        _TradeRow(tx: tx, isDark: isDark),
                        if (!isLast)
                          Divider(
                            height: 1,
                            color: isDark
                                ? AppColors.darkDivider
                                : AppColors.surfaceContainerLow,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Stat Cell ─────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label, value;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
}

// ── Trade Row ─────────────────────────────────────────────────────────────────

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.tx, required this.isDark});

  final Transaction tx;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isBuy = tx.type == TransactionType.buy;
    final typeColor = isBuy ? AppColors.positive : AppColors.negative;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 16,
            color: typeColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBuy ? 'Buy' : 'Sell',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(tx.date),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(tx.amount, tx.currency),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
              ),
            ),
            if (tx.quantity != null && tx.pricePerUnit != null)
              Text(
                '${NumberFormat('#,##0.####', 'en_US').format(tx.quantity!)} × '
                '${CurrencyFormatter.format(tx.pricePerUnit!, tx.currency)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
                ),
              ),
          ],
        ),
      ]),
    );
  }
}
