import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_colors.dart';
import '../../providers/net_worth_provider.dart';
import '../../providers/exchange_rate_provider.dart';
import '../../../domain/entities/app_user.dart';
import '../../providers/auth_providers.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/account_type.dart';
import '../../extensions/account_type_ui.dart';
import '../../providers/account_providers.dart';
import '../../widgets/accounts/account_form_sheet.dart';
import '../../widgets/holdings/holding_form_sheet.dart';
import '../../widgets/cards/card_form_sheet.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/transactions/transaction_form_sheet.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).valueOrNull;
    final totalBalance = ref.watch(totalNetWorthProvider);
    final rateAsync = ref.watch(exchangeRateProvider);
    final rate = usdToKrw(rateAsync);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final recentTxs = ref.watch(recentTransactionsProvider);

    return FeatureScaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: 0,
          bottom: 120,
        ),
        children: [
          // ── Frosted Header ──────────────────────────────────
          _FrostedHeader(user: user, isDark: isDark),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),

                // ── Net Worth Hero ───────────────────────────
                Text(
                  'Total Net Worth',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(totalBalance, 'KRW'),
                  style: textTheme.displayMedium?.copyWith(
                    letterSpacing: -2,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rateAsync.isLoading
                      ? 'Loading rate…'
                      : '1 USD = ₩${NumberFormat('#,###').format(rate.toInt())}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textSecondaryLight,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Quick Actions ────────────────────────────
                Builder(
                  builder: (ctx) => _QuickActions(
                    isDark: isDark,
                    onAddExpense: () => showTransactionFormSheet(ctx),
                    onAddHolding: () => showHoldingFormSheet(ctx),
                    onAddCard: () => showCardFormSheet(ctx),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Accounts Section ─────────────────────────
                _SectionHeader(
                  title: 'Accounts',
                  isDark: isDark,
                  onViewAll: () => context.go('/accounts'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Horizontal Account Cards ─────────────────────
          _AccountsCarousel(isDark: isDark, accounts: accounts),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 36),

                // ── Recent Activity ───────────────────────────
                _SectionHeader(
                  title: 'Recent Activity',
                  isDark: isDark,
                  onViewAll: () => context.go('/transactions'),
                ),
                const SizedBox(height: 16),

                _RecentActivity(txs: recentTxs, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Frosted Header ──────────────────────────────────────────────────────────

class _FrostedHeader extends StatelessWidget {
  const _FrostedHeader({required this.user, required this.isDark});

  final AppUser? user;
  final bool isDark;

  String get _displayName {
    final email = user?.email ?? '';
    if (email.isEmpty) return 'Welcome';
    return email.split('@').first;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: isDark
              ? AppColors.darkBackground.withValues(alpha: 0.8)
              : AppColors.surface.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // Avatar placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _displayName.isNotEmpty
                        ? _displayName[0].toUpperCase()
                        : 'J',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                ),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isDark, this.onViewAll});

  final String title;
  final bool isDark;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(title, style: textTheme.headlineMedium),
        const Spacer(),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'View All',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isDark,
    required this.onAddExpense,
    required this.onAddHolding,
    required this.onAddCard,
  });

  final bool isDark;
  final VoidCallback onAddExpense;
  final VoidCallback onAddHolding;
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (icon: Icons.add_card_rounded, label: 'Add\nExpense', onTap: onAddExpense),
      (icon: Icons.account_balance_rounded, label: 'Add\nHolding', onTap: onAddHolding),
      (icon: Icons.credit_card_rounded, label: 'Add\nCard', onTap: onAddCard),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: actions.map((a) {
        return Padding(
          padding: const EdgeInsets.only(right: 20),
          child: _QuickActionButton(
            icon: a.icon,
            label: a.label,
            isDark: isDark,
            onTap: a.onTap,
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal Account Carousel ──────────────────────────────────────────────

class _AccountsCarousel extends StatelessWidget {
  const _AccountsCarousel({
    required this.isDark,
    required this.accounts,
  });

  final bool isDark;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // "Add Account" card always first
          Builder(
            builder: (ctx) => _AccountCard(
              isPrimary: true,
              isDark: isDark,
              icon: Icons.add_rounded,
              label: 'Add Account',
              sublabel: accounts.isEmpty ? 'Get started' : '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
              value: '',
              onTap: () => showAccountFormSheet(ctx),
            ),
          ),
          // Real account cards
          ...accounts.map((a) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Builder(
                  builder: (ctx) => _AccountCard(
                    isPrimary: false,
                    isDark: isDark,
                    icon: a.type.icon,
                    label: a.name,
                    sublabel: a.type.label,
                    value: CurrencyFormatter.format(a.balance, a.currency),
                    onTap: () => showAccountFormSheet(ctx, existing: a),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.isPrimary,
    required this.isDark,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onTap,
  });

  final bool isPrimary;
  final bool isDark;
  final IconData icon;
  final String label;
  final String sublabel;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        height: 168,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [
                    AppColors.primaryGradientStart,
                    AppColors.primaryGradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary
              ? null
              : (isDark ? AppColors.darkCard : AppColors.surfaceCard),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isPrimary)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            else if (!isDark)
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.85)
                      : (isDark
                          ? AppColors.textSecondary
                          : AppColors.textTertiaryLight),
                ),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.65)
                        : (isDark
                            ? AppColors.textTertiary
                            : AppColors.textTertiaryLight),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.70)
                        : (isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight),
                  ),
                ),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isPrimary
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Activity ──────────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.txs, required this.isDark});
  final List<Transaction> txs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (txs.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined, size: 22,
                  color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
            ),
            const SizedBox(height: 12),
            Text('No transactions yet', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Builder(builder: (ctx) => GestureDetector(
              onTap: () => showTransactionFormSheet(ctx),
              child: Text('Tap to record one',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            )),
          ],
        ),
      );
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: txs.asMap().entries.map((entry) {
          final tx = entry.value;
          final isLast = entry.key == txs.length - 1;
          final isIncome = tx.type == TransactionType.income;
          final amountColor = isIncome ? AppColors.positive : AppColors.negative;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: tx.category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(tx.category.icon, size: 16, color: tx.category.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.title,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
                          Text(DateFormat('MMM d').format(tx.date),
                              style: TextStyle(fontSize: 11,
                                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
                        ],
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'}₩${NumberFormat('#,###').format(tx.amount.toInt())}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: amountColor),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1,
                    color: isDark ? AppColors.darkDivider : AppColors.surfaceContainerLow),
            ],
          );
        }).toList(),
      ),
    );
  }
}
