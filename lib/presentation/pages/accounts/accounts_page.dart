import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../shared/widgets/firestore_error_card.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/account_type.dart';
import '../../extensions/account_type_ui.dart';
import '../../providers/account_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/holding_providers.dart';
import '../../widgets/accounts/account_form_sheet.dart';
import '../../widgets/accounts/account_detail_sheet.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final accountsAsync = ref.watch(accountsStreamProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final linkedCashIds = ref.watch(linkedCashAccountIdsProvider);

    return FeatureScaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: 0,
          left: 20,
          right: 20,
          bottom: 120,
        ),
        children: [
          Row(children: [
            Text('Accounts', style: textTheme.headlineLarge),
            const Spacer(),
            GlassIconButton(
              icon: Icons.add_rounded,
              onPressed: () => showAccountFormSheet(context),
              color: AppColors.primary,
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'All your bank accounts and savings',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 24),

          // Total balance card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    'Liquid Cash',
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(CurrencyFormatter.format(totalBalance, 'KRW'),
                      style: textTheme.headlineLarge),
                ]),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: AppColors.primary, size: 22),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          Text('My Accounts', style: textTheme.headlineSmall),
          const SizedBox(height: 12),

          accountsAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LinearProgressIndicator()),
            error: (e, _) => FirestoreErrorCard(error: e, isDark: isDark),
            data: (accounts) {
              if (accounts.isEmpty) {
                return _EmptyAccountsState(isDark: isDark);
              }
              final accountById = {for (final a in accounts) a.id: a};
              // Accounts to show: all except those linked as cash sub-accounts
              final visible =
                  accounts.where((a) => !linkedCashIds.contains(a.id)).toList();

              return Column(
                children: visible.map((account) {
                  // Investment account with a linked cash account → merged tile
                  if (account.type == AccountType.investment &&
                      account.linkedCashAccountId != null) {
                    final cashAccount =
                        accountById[account.linkedCashAccountId];
                    if (cashAccount != null) {
                      return _MergedInvestmentTile(
                        investAccount: account,
                        cashAccount: cashAccount,
                        isDark: isDark,
                      );
                    }
                  }
                  return _AccountTile(account: account, isDark: isDark);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

}

// ── Merged Investment Tile ────────────────────────────────────────────────────

class _MergedInvestmentTile extends ConsumerWidget {
  const _MergedInvestmentTile({
    required this.investAccount,
    required this.cashAccount,
    required this.isDark,
  });
  final Account investAccount;
  final Account cashAccount;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsForAccountProvider(investAccount.id));
    final investedValue =
        holdings.fold(0.0, (s, h) => s + h.totalValue);
    final cashValue = cashAccount.balance;
    final totalValue = investedValue + cashValue;
    final currency = investAccount.currency;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showAccountDetailSheet(
            context,
            investAccount,
            cashAccount: cashAccount,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.show_chart_rounded,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      investAccount.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Investment',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    CurrencyFormatter.format(totalValue, currency),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ]),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textTertiaryLight),
              ]),

              const SizedBox(height: 12),

              // Invested / Cash breakdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBorder.withValues(alpha: 0.5)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Expanded(
                    child: _BreakdownCell(
                      label: 'Invested',
                      value: CurrencyFormatter.format(investedValue, currency),
                      color: AppColors.primary,
                      isDark: isDark,
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 32,
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightBorder),
                  Expanded(
                    child: _BreakdownCell(
                      label: 'Cash',
                      value: CurrencyFormatter.format(cashValue, currency),
                      color: AppColors.positive,
                      isDark: isDark,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _BreakdownCell extends StatelessWidget {
  const _BreakdownCell({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });
  final String label, value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.textTertiaryLight)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis),
      ]);
}

// ── Regular Account Tile ──────────────────────────────────────────────────────

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.isDark});
  final Account account;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInvestment = account.type == AccountType.investment;
    final displayBalance = isInvestment
        ? ref.watch(holdingsForAccountProvider(account.id))
            .fold(0.0, (s, h) => s + h.totalValue)
        : ref.watch(computedAccountBalanceProvider(account.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(account.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.negative.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: AppColors.negative, size: 22),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => _delete(context, ref),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showAccountDetailSheet(context, account),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(account.type.icon,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    account.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.type.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  CurrencyFormatter.format(displayBalance, account.currency),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight),
                ),
                const SizedBox(height: 2),
                Text(
                  account.currency,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.textTertiaryLight),
                ),
              ]),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.textTertiary
                      : AppColors.textTertiaryLight),
            ]),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Account'),
          content: Text('Delete "${account.name}"? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    try {
      await ref
          .read(accountRepositoryProvider)
          .deleteAccount(user.uid, account.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyAccountsState extends StatelessWidget {
  const _EmptyAccountsState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(children: [
        Icon(Icons.account_balance_outlined,
            size: 40,
            color:
                isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
        const SizedBox(height: 12),
        Text('No accounts yet', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Tap + to add your first account',
          style: textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),
        GlassButton(
          label: 'Add Account',
          icon: Icons.add_rounded,
          onPressed: () => showAccountFormSheet(context),
        ),
      ]),
    );
  }
}
