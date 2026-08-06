import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/sheet_account.dart';
import '../../providers/sheets_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/money.dart';
import '../../shared/widgets/error_card.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../shared/widgets/updated_at_label.dart';
import '../../widgets/account_picker_field.dart' show AccountMonogram;

/// The `Type` values this page lists, in display order. Everything else in the
/// tab — `Brokerage` (already on the Dashboard) and `Crypto` — is left out.
const _kCreditType = 'Credit';
const _kBankType = 'Bank';

/// Balances straight from the sheet's `Accounts` tab: what is owed on each card
/// and what is sitting in each bank account.
///
/// Read-only, and it costs no extra network call — [accountsProvider] is
/// already fetched for the Transactions page's currency labels.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(accountsProvider);

    return GradientBackground(
      child: FeatureScaffold(
        title: 'Accounts',
        loading: ref.watch(isFetchingProvider('accountsProvider')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(accountsProvider),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(accountsProvider),
          child: async.when(
            loading: () => const _LoadingView(),
            // While a refetch is in flight, `when` re-surfaces the previous
            // state — showing a stale error card during the reload reads as
            // "still broken", so show the loading view until it resolves.
            error: (e, _) => async.isLoading
                ? const _LoadingView()
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 80),
                      ErrorCard(
                        error: e,
                        isDark: isDark,
                        onRetry: () => ref.invalidate(accountsProvider),
                      ),
                    ],
                  ),
            data: (accounts) => _AccountsBody(
              credit: accounts.ofType(_kCreditType),
              bank: accounts.ofType(_kBankType),
              updatedAt: ref.watch(accountsUpdatedAtProvider),
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody({
    required this.credit,
    required this.bank,
    required this.updatedAt,
    required this.isDark,
  });

  final List<SheetAccount> credit;
  final List<SheetAccount> bank;
  final DateTime? updatedAt;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (credit.isEmpty && bank.isEmpty) {
      return _EmptyState(isDark: isDark);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        UpdatedAtLabel(updatedAt: updatedAt, isDark: isDark),
        if (credit.isNotEmpty) ...[
          _SectionLabel('Credit cards', isDark: isDark),
          const SizedBox(height: 8),
          for (final a in credit) _AccountRow(account: a, isDark: isDark),
        ],
        if (credit.isNotEmpty && bank.isNotEmpty) const SizedBox(height: 12),
        if (bank.isNotEmpty) ...[
          _SectionLabel('Bank accounts', isDark: isDark),
          const SizedBox(height: 8),
          for (final a in bank) _AccountRow(account: a, isDark: isDark),
        ],
      ],
    );
  }
}

/// One account: its monogram and name, with the sheet's Current Balance on the
/// right. The balance is shown **exactly as the sheet stores it**, sign
/// included — the app applies no sign convention of its own.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.isDark});

  final SheetAccount account;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final balance = account.currentBalance;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AccountMonogram(name: account.name),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            // An em dash, not 0 — a blank cell is "the sheet didn't say", and a
            // zero balance is a real, different thing (a paid-off card).
            balance == null ? '—' : money(balance, account.currency),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: balance == null
                  ? (isDark
                      ? AppColors.textTertiary
                      : AppColors.textTertiaryLight)
                  : (isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.textTertiary : AppColors.textTertiaryLight;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.account_balance_rounded, size: 44, color: color),
        const SizedBox(height: 12),
        Text(
          'No credit or bank accounts in the sheet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget block(double height) => Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 16),
        block(62),
        block(62),
        const SizedBox(height: 12),
        block(62),
        block(62),
      ],
    );
  }
}
