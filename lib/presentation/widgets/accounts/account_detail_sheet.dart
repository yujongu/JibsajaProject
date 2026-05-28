import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../providers/price_provider.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/form_sheet_widgets.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/account_type.dart';
import '../../extensions/account_type_ui.dart';
import '../../providers/account_providers.dart';
import '../../../domain/entities/holding.dart';
import '../../extensions/holding_type_ui.dart';
import '../../providers/holding_providers.dart';
import 'account_form_sheet.dart';

Future<void> showAccountDetailSheet(
  BuildContext context,
  Account account, {
  Account? cashAccount,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        AccountDetailSheet(account: account, cashAccount: cashAccount),
  );
}

class AccountDetailSheet extends ConsumerWidget {
  const AccountDetailSheet({
    super.key,
    required this.account,
    this.cashAccount,
  });
  final Account account;
  final Account? cashAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final holdings = ref.watch(holdingsForAccountProvider(account.id));
    final livePrices = ref.watch(livePricesProvider);
    final computedBalance = ref.watch(computedAccountBalanceProvider(account.id));

    final investedValue = holdings.fold(0.0, (s, h) => s + h.totalValue);
    final cashValue = cashAccount != null
        ? ref.watch(computedAccountBalanceProvider(cashAccount!.id))
        : 0.0;
    final totalValue = investedValue + (cashAccount != null ? cashValue : 0);
    final currency = account.currency;
    final isMerged = cashAccount != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: (MediaQuery.viewInsetsOf(context).bottom > 0
                ? MediaQuery.viewInsetsOf(context).bottom
                : MediaQuery.paddingOf(context).bottom) +
            32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetDragHandle(isDark: isDark),
            const SizedBox(height: 20),

            // Header row
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(account.type.icon,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(account.name, style: textTheme.titleLarge),
                  Text(
                    isMerged
                        ? 'Investment · ${account.currency}'
                        : '${account.type.label} · ${account.currency}',
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ]),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showAccountFormSheet(context, existing: account);
                },
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ]),
            const SizedBox(height: 20),

            // Balance card — merged or single
            if (isMerged) ...[
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Account Value',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.format(totalValue, currency),
                        style: textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _BalanceRow(
                          label: 'Invested',
                          value: CurrencyFormatter.format(investedValue, currency),
                          icon: Icons.show_chart_rounded,
                          color: AppColors.primary,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceRow(
                          label: 'Cash (${cashAccount!.name})',
                          value: CurrencyFormatter.format(cashValue, currency),
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.positive,
                          isDark: isDark,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ] else ...[
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Balance',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondaryLight,
                          )),
                      const SizedBox(height: 4),
                      Text(CurrencyFormatter.format(computedBalance, currency),
                          style: textTheme.headlineMedium),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(currency,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 24),

            // Holdings section
            Row(children: [
              Text('Holdings', style: textTheme.titleMedium),
              const SizedBox(width: 8),
              if (livePrices.isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary.withValues(alpha: 0.6)),
                ),
            ]),
            const SizedBox(height: 12),

            if (holdings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.show_chart_outlined,
                        size: 32,
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.textTertiaryLight),
                    const SizedBox(height: 8),
                    Text(
                      'No positions in this account',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ]),
                ),
              )
            else
              ...holdings.map((h) => _HoldingRow(
                    holding: h,
                    isDark: isDark,
                    hasLivePrice: livePrices.valueOrNull?.containsKey(h.ticker) ?? false,
                  )),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}

// ── Balance Row (inside merged card) ─────────────────────────────────────────

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.textTertiaryLight),
                  overflow: TextOverflow.ellipsis),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

// ── Holding Row ───────────────────────────────────────────────────────────────

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({
    required this.holding,
    required this.isDark,
    required this.hasLivePrice,
  });
  final Holding holding;
  final bool isDark;
  final bool hasLivePrice;

  @override
  Widget build(BuildContext context) {
    final isPositive = holding.gainLoss >= 0;
    final gainColor = isPositive ? AppColors.positive : AppColors.negative;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: holding.type.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(holding.type.icon, size: 16, color: holding.type.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Text(holding.ticker,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight)),
              if (hasLivePrice) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('LIVE',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.positive)),
                ),
              ],
            ]),
            Text(
              '${NumberFormat('#,##0.####', 'en_US').format(holding.quantity)} × '
              '${CurrencyFormatter.format(holding.currentPrice, holding.currency)}',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            CurrencyFormatter.format(holding.totalValue, holding.currency),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLight),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 10,
              color: gainColor,
            ),
            Text(
              '${holding.gainLossPercent.toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: gainColor),
            ),
          ]),
        ]),
      ]),
    );
  }

}
