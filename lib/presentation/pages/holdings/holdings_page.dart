import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../providers/net_worth_provider.dart';
import '../../providers/price_provider.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_button.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../../domain/entities/holding.dart';
import '../../extensions/holding_type_ui.dart';
import '../../providers/holding_providers.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/transactions/transaction_form_sheet.dart';
import '../../widgets/holdings/holding_detail_sheet.dart';

enum HoldingSort { alphabetical, mostInvested, mostProfited }

extension HoldingSortExt on HoldingSort {
  String get label {
    switch (this) {
      case HoldingSort.alphabetical:  return 'A → Z';
      case HoldingSort.mostInvested:  return 'Most Invested';
      case HoldingSort.mostProfited:  return 'Best Return %';
    }
  }
  IconData get icon {
    switch (this) {
      case HoldingSort.alphabetical:  return Icons.sort_by_alpha_rounded;
      case HoldingSort.mostInvested:  return Icons.attach_money_rounded;
      case HoldingSort.mostProfited:  return Icons.trending_up_rounded;
    }
  }
}

class HoldingsPage extends ConsumerStatefulWidget {
  const HoldingsPage({super.key});

  @override
  ConsumerState<HoldingsPage> createState() => _HoldingsPageState();
}

class _HoldingsPageState extends ConsumerState<HoldingsPage> {
  final _portfolioCardKey = GlobalKey();
  HoldingSort _sort = HoldingSort.mostInvested;

  double _portfolioCardBottom() {
    final box = _portfolioCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    return box.localToGlobal(Offset.zero).dy + box.size.height;
  }

  List<Holding> _sorted(List<Holding> holdings) {
    final list = [...holdings];
    switch (_sort) {
      case HoldingSort.alphabetical:
        list.sort((a, b) => a.ticker.compareTo(b.ticker));
      case HoldingSort.mostInvested:
        list.sort((a, b) => b.totalValue.compareTo(a.totalValue));
      case HoldingSort.mostProfited:
        list.sort((a, b) => b.gainLossPercent.compareTo(a.gainLossPercent));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    final holdings = _sorted(ref.watch(aggregateHoldingsProvider));
    final livePrices = ref.watch(livePricesProvider);
    final totalValue = ref.watch(totalPortfolioInKrwProvider);
    final totalGainLoss = ref.watch(totalPortfolioGainLossInKrwProvider);
    final isLoadingTx = ref.watch(transactionsStreamProvider).isLoading;

    final gainLossPositive = totalGainLoss >= 0;
    final gainLossColor = gainLossPositive ? AppColors.positive : AppColors.negative;
    final isPriceLoading = livePrices.isLoading;

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
              Text('Holdings', style: textTheme.headlineLarge),
              const Spacer(),
              if (isPriceLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => ref.invalidate(livePricesProvider),
                tooltip: 'Refresh prices',
                style: IconButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                ),
              ),
              GlassIconButton(
                icon: Icons.add_rounded,
                onPressed: () => showTransactionFormSheet(
                  context,
                  initialType: TransactionType.buy,
                  anchorBottom: _portfolioCardBottom(),
                ),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text(
              'Derived from your trade history',
              style: textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 6),
            if (!isPriceLoading && livePrices.hasValue && livePrices.value!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
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
          ]),
          const SizedBox(height: 24),

          // Portfolio value card — key used to anchor the Add Transaction sheet
          GlassCard(
            key: _portfolioCardKey,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portfolio Value',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(CurrencyFormatter.format(totalValue, 'KRW'), style: textTheme.headlineLarge),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gainLossColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        gainLossPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 13,
                        color: gainLossColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatGainLoss(totalGainLoss),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: gainLossColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (holdings.isNotEmpty)
            _AllocationChart(holdings: holdings, isDark: isDark),

          if (holdings.isNotEmpty)
            const SizedBox(height: 24),

          Row(
            children: [
              Text('Positions', style: textTheme.headlineSmall),
              const Spacer(),
              _SortButton(
                current: _sort,
                isDark: isDark,
                onChanged: (s) => setState(() => _sort = s),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isLoadingTx)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: LinearProgressIndicator(),
            )
          else if (holdings.isEmpty)
            _EmptyHoldingsState(isDark: isDark)
          else
            Column(
              children: holdings
                  .map((h) => _HoldingTile(
                        holding: h,
                        isDark: isDark,
                        hasLivePrice:
                            livePrices.valueOrNull?.containsKey(h.ticker) ?? false,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  static String _formatGainLoss(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${NumberFormat('#,##0', 'en_US').format(v.toInt())}';
  }
}

// ── Holding Tile ──────────────────────────────────────────────────────────────

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({
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
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => showHoldingDetailSheet(context, holding, hasLivePrice: hasLivePrice),
        child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: holding.type.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(holding.type.icon, size: 20, color: holding.type.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      holding.ticker,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (hasLivePrice) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.positive.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.positive,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ]),
                  Text(
                    holding.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${NumberFormat('#,##0.####', 'en_US').format(holding.quantity)} units',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(holding.totalValue, holding.currency),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: gainColor,
                    ),
                    Text(
                      '${holding.gainLossPercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: gainColor),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.format(holding.currentPrice, holding.currency),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

}

// ── Sort Button ───────────────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.current,
    required this.isDark,
    required this.onChanged,
  });
  final HoldingSort current;
  final bool isDark;
  final ValueChanged<HoldingSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(current.icon, size: 13,
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
          const SizedBox(width: 5),
          Text(current.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              )),
          const SizedBox(width: 3),
          Icon(Icons.expand_more_rounded, size: 14,
              color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final isDarkPicker = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDarkPicker ? AppColors.darkCard : AppColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDarkPicker ? AppColors.darkBorder : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ...HoldingSort.values.map((s) => ListTile(
              leading: Icon(s.icon,
                  color: s == current ? AppColors.primary : (isDarkPicker
                      ? AppColors.textSecondary : AppColors.textSecondaryLight),
                  size: 20),
              title: Text(s.label,
                  style: TextStyle(
                    fontWeight: s == current ? FontWeight.w700 : FontWeight.w500,
                    color: s == current ? AppColors.primary : (isDarkPicker
                        ? AppColors.textPrimary : AppColors.textPrimaryLight),
                  )),
              trailing: s == current
                  ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onChanged(s);
              },
            )),
          ],
        ),
      ),
    );
  }
}

// ── Allocation Pie Chart ──────────────────────────────────────────────────────

class _AllocationChart extends StatefulWidget {
  const _AllocationChart({required this.holdings, required this.isDark});
  final List<Holding> holdings;
  final bool isDark;

  @override
  State<_AllocationChart> createState() => _AllocationChartState();
}

class _AllocationChartState extends State<_AllocationChart> {
  int _touched = -1;

  static const _palette = [
    Color(0xFF6C63FF),
    Color(0xFF00C6A2),
    Color(0xFFFF6B6B),
    Color(0xFFFFB74D),
    Color(0xFF4FC3F7),
    Color(0xFFA5D6A7),
    Color(0xFFF48FB1),
    Color(0xFF80DEEA),
  ];

  @override
  Widget build(BuildContext context) {
    final holdings = widget.holdings;
    final isDark = widget.isDark;
    final textTheme = Theme.of(context).textTheme;

    final total = holdings.fold<double>(0, (s, h) => s + h.totalValue);
    if (total <= 0) return const SizedBox.shrink();

    final sections = holdings.asMap().entries.map((e) {
      final i = e.key;
      final h = e.value;
      final pct = h.totalValue / total;
      final isTouched = i == _touched;
      final color = _palette[i % _palette.length];
      return PieChartSectionData(
        value: h.totalValue,
        color: color,
        radius: isTouched ? 56 : 48,
        title: isTouched ? '${(pct * 100).toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    final touchedHolding = _touched >= 0 && _touched < holdings.length
        ? holdings[_touched]
        : null;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allocation', style: textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 28,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response?.touchedSection == null) {
                            _touched = -1;
                          } else {
                            _touched = response!
                                .touchedSection!.touchedSectionIndex;
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (touchedHolding != null) ...[
                      Text(
                        touchedHolding.ticker,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                            touchedHolding.totalValue, touchedHolding.currency),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ] else
                      ...holdings.take(5).toList().asMap().entries.map((e) {
                        final i = e.key;
                        final h = e.value;
                        final pct = h.totalValue / total * 100;
                        final color = _palette[i % _palette.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h.ticker,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimary
                                      : AppColors.textPrimaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ]),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyHoldingsState extends StatelessWidget {
  const _EmptyHoldingsState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.show_chart_outlined,
              size: 40,
              color: isDark ? AppColors.textTertiary : AppColors.textTertiaryLight),
          const SizedBox(height: 12),
          Text('No holdings yet', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Record a Buy trade in Transactions to add a position',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: 'Add Buy Trade',
            icon: Icons.add_rounded,
            onPressed: () => showTransactionFormSheet(
              context,
              initialType: TransactionType.buy,
            ),
          ),
        ],
      ),
    );
  }
}
