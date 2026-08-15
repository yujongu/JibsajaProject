import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/sheet_holding.dart';
import '../../providers/sheets_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/money.dart';
import '../../shared/widgets/error_card.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../shared/widgets/updated_at_label.dart';
import '../../widgets/account_picker_field.dart' show accountIdentityColor;

/// Every stock position from the sheet's `Holdings` tab, ranked, with each
/// position's share of the portfolio.
///
/// Read-only. Split into one section per currency — the app takes no FX feed,
/// so ₩ and $ positions are never added together.
class HoldingsPage extends ConsumerWidget {
  const HoldingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(holdingsProvider);

    return GradientBackground(
      child: FeatureScaffold(
        title: 'Holdings',
        loading: ref.watch(isFetchingProvider('holdingsProvider')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(holdingsProvider),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(holdingsProvider),
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
                        onRetry: () => ref.invalidate(holdingsProvider),
                      ),
                    ],
                  ),
            data: (_) => _HoldingsBody(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

class _HoldingsBody extends ConsumerWidget {
  const _HoldingsBody({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(holdingsSectionsProvider);
    if (sections.isEmpty) return _EmptyState(isDark: isDark);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        UpdatedAtLabel(
          updatedAt: ref.watch(holdingsUpdatedAtProvider),
          isDark: isDark,
        ),
        for (final section in sections) ...[
          _SectionHeaderCard(section: section, isDark: isDark),
          // The sort header repeats above every section because a column
          // header belongs to the table under it — but all of them read and
          // write the one shared order, so the sections never disagree.
          const _SortHeader(),
          for (final h in section.holdings)
            _HoldingRow(holding: h, section: section, isDark: isDark),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// One currency's totals, with the whole section's split as a stacked bar.
class _SectionHeaderCard extends StatelessWidget {
  const _SectionHeaderCard({required this.section, required this.isDark});

  final CurrencyHoldings section;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final currency = section.currency;
    final gain = section.unrealizedGain;
    final ret = section.returnFraction;
    final up = gain >= 0;
    final gainColor = up ? AppColors.positive : AppColors.negative;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency == null ? 'Market value' : '$currency · Market value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color:
                  isDark ? AppColors.textTertiary : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(section.marketValue, currency),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Cost ${money(section.baseValue, currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 15,
                color: gainColor,
              ),
              const SizedBox(width: 2),
              Text(
                signedMoney(gain, currency),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: gainColor,
                ),
              ),
              if (ret != null) ...[
                const SizedBox(width: 7),
                Text(
                  signedPercent(ret),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gainColor,
                  ),
                ),
              ],
            ],
          ),
          _StackedBar(section: section),
        ],
      ),
    );
  }
}

/// The section's positions as one proportional bar, each segment in the
/// symbol's identity color so it maps onto the dots on the rows below.
class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.section});

  final CurrencyHoldings section;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (final h in section.holdings)
        if (section.share(h) > 0) h,
    ];
    if (segments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                // A hairline is still a segment: a 0.5% position must read as
                // "nearly nothing" rather than vanish.
                flex: _flex(section.share(segments[i])),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accountIdentityColor(segments[i].symbol),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _flex(double share) {
    final flex = (share * 1000).round();
    return flex < 1 ? 1 : flex;
  }
}

/// The column header that orders the list. Tapping a column sorts by it;
/// tapping the active column reverses the direction.
class _SortHeader extends StatelessWidget {
  const _SortHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          _SortCell(field: HoldingSort.symbol, label: 'Symbol', leading: true),
          _SortCell(field: HoldingSort.value, label: 'Value'),
          _SortCell(field: HoldingSort.gain, label: 'Gain'),
          _SortCell(field: HoldingSort.gainPercent, label: 'Gain %'),
        ],
      ),
    );
  }
}

class _SortCell extends ConsumerWidget {
  const _SortCell({
    required this.field,
    required this.label,
    this.leading = false,
  });

  final HoldingSort field;
  final String label;

  /// The name column, which takes the remaining width and aligns left.
  final bool leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = ref.watch(holdingOrderProvider);
    final active = order.field == field;
    final color = active
        ? AppColors.primary
        : (isDark ? AppColors.textTertiary : AppColors.textTertiaryLight);

    // An arrow means nothing on a name column, so it says which way the
    // alphabet runs instead.
    final marker = !active
        ? null
        : field == HoldingSort.symbol
            ? (order.dir == SortDir.asc ? 'A–Z' : 'Z–A')
            : (order.dir == SortDir.asc ? '▲' : '▼');

    final cell = GestureDetector(
      // Opaque so the whole padded cell is the tap target — 10px type is a
      // small thing to hit otherwise.
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(holdingOrderProvider.notifier).tap(field),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: leading ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: color,
              ),
            ),
            if (marker != null) ...[
              const SizedBox(width: 3),
              Text(
                marker,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return leading ? Expanded(child: cell) : cell;
  }
}

/// One position: what it is worth now, what it has gained, and how much of the
/// portfolio it is.
class _HoldingRow extends StatelessWidget {
  const _HoldingRow({
    required this.holding,
    required this.section,
    required this.isDark,
  });

  final SheetHolding holding;
  final CurrencyHoldings section;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final currency = holding.currency.isEmpty ? null : holding.currency;
    final color = accountIdentityColor(holding.symbol);
    final marketValue = holding.marketValue;
    final share = section.share(holding);
    final subtitle = _subtitle(currency);

    final mutedColor =
        isDark ? AppColors.textTertiary : AppColors.textTertiaryLight;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.name ?? holding.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (holding.name != null)
                      Text(
                        holding.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                // An em dash, not 0 — a blank cell is "the sheet didn't say",
                // and a zero position is a real, different thing.
                marketValue == null ? '—' : money(marketValue, currency),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: marketValue == null
                      ? mutedColor
                      : (isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _GainLabel(holding: holding, currency: currency, muted: mutedColor),
            ],
          ),
          if (share > 0) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.surfaceContainerLow,
                        ),
                        FractionallySizedBox(
                          widthFactor: share.clamp(0.0, 1.0),
                          child: Container(height: 6, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  currency == null
                      ? _sharePercent(share)
                      : '${_sharePercent(share)} of $currency',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// "20 sh · avg $118.40 → $190.10", skipping whatever the sheet left blank.
  String? _subtitle(String? currency) {
    final parts = <String>[];
    final qty = holding.quantity;
    if (qty != null) parts.add('${plainNumber(qty)} sh');

    final avg = holding.avgPrice;
    final now = holding.currentPrice;
    if (avg != null && now != null) {
      parts.add('avg ${money(avg, currency)} → ${money(now, currency)}');
    } else if (avg != null) {
      parts.add('avg ${money(avg, currency)}');
    } else if (now != null) {
      parts.add('now ${money(now, currency)}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// A share under 1% keeps a decimal, so a tiny position does not read as 0%.
  static String _sharePercent(double share) {
    final pct = share * 100;
    return pct < 1 ? '${pct.toStringAsFixed(1)}%' : '${pct.round()}%';
  }
}

class _GainLabel extends StatelessWidget {
  const _GainLabel({
    required this.holding,
    required this.currency,
    required this.muted,
  });

  final SheetHolding holding;
  final String? currency;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final gain = holding.unrealizedGain;
    if (gain == null) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
      );
    }

    final up = gain >= 0;
    final color = up ? AppColors.positive : AppColors.negative;
    final ret = holding.returnFraction;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 1),
        Text(
          signedMoney(gain, currency),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (ret != null) ...[
          const SizedBox(width: 6),
          Text(
            signedPercent(ret),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
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
    final color = isDark ? AppColors.textTertiary : AppColors.textTertiaryLight;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.show_chart_rounded, size: 44, color: color),
        const SizedBox(height: 12),
        Text(
          // Names the filter rather than claiming the tab is empty — a sheet
          // full of positions in other currencies lands here too.
          'No KRW or USD positions in the sheet',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
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
        block(112),
        const SizedBox(height: 20),
        block(84),
        block(84),
        block(84),
      ],
    );
  }
}
