import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/sheet_transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';

/// One row in a transaction list: category-colored icon tile, title, account
/// and date, amount, and a type badge.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    required this.isDark,
    this.currency,
  });
  final SheetTransaction tx;
  final bool isDark;

  /// Currency code of [tx]'s account, or null when the sheet's `Accounts` tab
  /// does not name one.
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final isPurchase = tx.type == TransactionType.purchase;
    final cat = tx.category;
    // A purchase is colored by its category, not by its type — otherwise every
    // expense on screen is the same red. Uncategorized rows fall back to Misc.,
    // which is where the month summary buckets them too.
    final color = isPurchase
        ? (cat ?? TransactionCategory.misc).color(isDark)
        : _typeColor(tx.type);

    final title = switch (tx.type) {
      TransactionType.purchase => tx.description.isNotEmpty
          ? tx.description
          : (cat?.label ?? 'Purchase'),
      // Transfer rows carry no ticker; show their note (the trade description).
      TransactionType.transfer =>
        tx.description.isNotEmpty ? tx.description : 'Transfer',
      TransactionType.deposit =>
        tx.description.isNotEmpty ? tx.description : 'Deposit',
      TransactionType.unknown => tx.description.isNotEmpty
          ? tx.description
          : (tx.rawType ?? tx.type.label),
      _ => tx.ticker ?? tx.type.label,
    };

    final subtitleParts = <String>[
      tx.account,
      DateFormat('MMM d, yyyy').format(tx.date),
      if (!isPurchase && tx.quantity != null && tx.price != null)
        '${plainNumber(tx.quantity!)} @ ${plainNumber(tx.price!)}',
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
              switch (tx.type) {
                TransactionType.purchase =>
                  cat?.icon ?? Icons.shopping_bag_rounded,
                TransactionType.buy => Icons.trending_up_rounded,
                TransactionType.sell => Icons.trending_down_rounded,
                TransactionType.transfer => Icons.swap_horiz_rounded,
                TransactionType.deposit => Icons.arrow_downward_rounded,
                TransactionType.unknown => Icons.help_outline_rounded,
              },
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
                money(tx.computedAmount, currency),
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
                // An unrecognized row is badged with the sheet's own wording.
                tx.rawType ?? tx.type.label,
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
    case TransactionType.transfer: return AppColors.secondaryFallback;
    case TransactionType.deposit:  return AppColors.positive;
    case TransactionType.unknown:  return AppColors.textTertiaryLight;
  }
}
