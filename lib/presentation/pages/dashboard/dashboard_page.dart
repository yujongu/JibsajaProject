import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/dashboard_summary.dart';
import '../../providers/sheets_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/error_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../shared/widgets/updated_at_label.dart';
import '../settings/settings_page.dart';
import 'fx_sparkline.dart';

String _krw(double v) => '₩${NumberFormat('#,##0', 'en_US').format(v)}';
String _usd(double v) => '\$${NumberFormat('#,##0.##', 'en_US').format(v)}';
String _rate(double v) => NumberFormat('#,##0.0', 'en_US').format(v);
String _signedPct(double frac) {
  final pct = NumberFormat('#,##0.0', 'en_US').format(frac.abs() * 100);
  return '${frac < 0 ? '−' : '+'}$pct%';
}

/// Read-only portfolio snapshot sourced entirely from the sheet's `DashboardDB1`
/// tab — the figures are authored by the spreadsheet, so they always match the
/// user's Google Sheet dashboard.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(dashboardProvider);

    return GradientBackground(
      child: FeatureScaffold(
        title: 'Dashboard',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
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
                        onRetry: () => ref.invalidate(dashboardProvider),
                      ),
                    ],
                  ),
            data: (d) => _DashboardBody(
              summary: d,
              isDark: isDark,
              updatedAt: ref.watch(dashboardUpdatedAtProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.summary,
    required this.isDark,
    required this.updatedAt,
  });
  final DashboardSummary summary;
  final bool isDark;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        UpdatedAtLabel(updatedAt: updatedAt, isDark: isDark),
        _NetWorthHero(summary: summary),
        const SizedBox(height: 20),
        _SectionLabel('Holdings', isDark: isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                korean: '보유 KRW 현금',
                english: 'KRW cash',
                value: _krw(summary.krwCash),
                icon: Icons.account_balance_wallet_rounded,
                accent: AppColors.primary,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                korean: '보유 USD 현금',
                english: 'USD cash',
                value: _usd(summary.usdCash),
                icon: Icons.attach_money_rounded,
                accent: AppColors.secondaryFallback,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                korean: '보유 한국 주식',
                english: 'KR stocks',
                value: _krw(summary.krStocksKrw),
                icon: Icons.show_chart_rounded,
                accent: AppColors.primary,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                korean: '보유 미국 주식',
                english: 'US stocks',
                value: _usd(summary.usStocksUsd),
                icon: Icons.public_rounded,
                accent: AppColors.secondaryFallback,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionLabel('Totals', isDark: isDark),
        const SizedBox(height: 8),
        _TotalRow(
          korean: '총 보유 현금',
          english: 'Total cash',
          krw: summary.totalCashKrw,
          usd: summary.totalCashUsd,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _TotalRow(
          korean: '총 보유 주식',
          english: 'Total stocks',
          krw: summary.totalStocksKrw,
          usd: summary.totalStocksUsd,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _SectionLabel('Investment', isDark: isDark),
        const SizedBox(height: 8),
        _InvestmentCard(summary: summary, isDark: isDark),
        const SizedBox(height: 20),
        _SectionLabel('USD / KRW', isDark: isDark),
        const SizedBox(height: 8),
        _FxCard(summary: summary, isDark: isDark),
      ],
    );
  }
}

/// Premium gradient hero showing net worth (총 자산) and total return.
class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final up = summary.returnRate >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGradientStart,
            AppColors.primaryGradientEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '총 자산 · Total Assets',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              _ReturnPill(returnRate: summary.returnRate, up: up),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _krw(summary.totalAssetsKrw),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ ${_usd(summary.totalAssetsUsd)}  ·  환율 ${_rate(summary.exchangeRate)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnPill extends StatelessWidget {
  const _ReturnPill({required this.returnRate, required this.up});
  final double returnRate;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            _signedPct(returnRate),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four core holding cards.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.korean,
    required this.english,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  final String korean;
  final String english;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  english,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            korean,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A total line showing the KRW figure with a USD sub-figure to the right.
class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.korean,
    required this.english,
    required this.krw,
    required this.usd,
    required this.isDark,
  });

  final String korean;
  final String english;
  final double krw;
  final double usd;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDecoration(isDark),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  korean,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  english,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _krw(krw),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '≈ ${_usd(usd)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({required this.summary, required this.isDark});
  final DashboardSummary summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final up = summary.returnRate >= 0;
    final returnColor = up ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
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
                      '총 투자 금액',
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
                      _krw(summary.totalInvestedKrw),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ ${_usd(summary.totalInvestedUsd)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '총 수익률',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textTertiary
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        up
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: returnColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _signedPct(summary.returnRate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: returnColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FxCard extends StatelessWidget {
  const _FxCard({required this.summary, required this.isDark});
  final DashboardSummary summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final history = summary.fxHistory;
    final hasHistory = history.length >= 2;

    double min = 0, max = 0;
    if (hasHistory) {
      min = history.first.rate;
      max = history.first.rate;
      for (final p in history) {
        if (p.rate < min) min = p.rate;
        if (p.rate > max) max = p.rate;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USD / KRW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₩${_rate(summary.exchangeRate)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasHistory)
                Text(
                  '${history.length}d · ${_rate(min)}–${_rate(max)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                  ),
                ),
            ],
          ),
          if (hasHistory) ...[
            const SizedBox(height: 12),
            FxSparkline(points: history, color: AppColors.primary),
          ],
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

BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(16),
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
    );

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget block(double height) => Container(
          height: height,
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
        block(110),
        const SizedBox(height: 20),
        Row(children: [Expanded(child: block(96)), const SizedBox(width: 12), Expanded(child: block(96))]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: block(96)), const SizedBox(width: 12), Expanded(child: block(96))]),
        const SizedBox(height: 20),
        block(64),
        const SizedBox(height: 10),
        block(64),
        const SizedBox(height: 20),
        block(120),
      ],
    );
  }
}
