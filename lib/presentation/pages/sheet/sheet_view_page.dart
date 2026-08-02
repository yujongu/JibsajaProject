import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/sheet_transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_summary.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../../providers/sheets_providers.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/error_card.dart';
import '../../shared/widgets/gradient_scaffold.dart';
import '../../shared/widgets/updated_at_label.dart';
import '../../widgets/add_transaction_sheet.dart';

/// Formats a bare number with grouping and up to 2 decimals. No currency
/// symbol — the sheet stores plain numbers and there is no currency source.
String _num(double v) => NumberFormat('#,##0.##', 'en_US').format(v);

class SheetViewPage extends ConsumerWidget {
  const SheetViewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(transactionsProvider);

    return GradientBackground(
      child: FeatureScaffold(
        title: 'Transactions',
        loading: ref.watch(isFetchingProvider('transactionsProvider')),
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
            // While a refetch is in flight, `when` re-surfaces the previous
            // state — showing a stale error card during the reload reads as
            // "still broken", so show the loading list until it resolves.
            error: (e, _) => async.isLoading
                ? const _LoadingList()
                : ListView(
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
                : _TransactionsList(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

/// How long the month change takes, for both the card slide and the list fade.
const _kMonthTransition = Duration(milliseconds: 260);

/// How far the summary card travels, as a fraction of its own width. Kept small
/// on purpose — paired with the fade this reads as restraint, where a full-width
/// sweep would fling the card into the screen edges.
const _kSlideExtent = 0.2;

/// AnimatedSwitcher's default layoutBuilder leaves outgoing children
/// unpositioned, so while both the old and new child are mounted the Stack
/// sizes itself to their union — the enclosing AnimatedSize sees that inflated
/// size for the whole crossfade and only learns the real target size once the
/// old child is removed at the very end, producing a stall-then-snap resize
/// instead of a continuous one. Positioning the outgoing children excludes
/// them from the Stack's sizing pass, so AnimatedSize can track the incoming
/// child's size from the moment the switch starts.
Widget _topAlignedSwitcherLayout(Widget? currentChild, List<Widget> previousChildren) {
  return Stack(
    alignment: Alignment.topCenter,
    children: [
      for (final child in previousChildren)
        Positioned(top: 0, left: 0, right: 0, child: child),
      ?currentChild,
    ],
  );
}

/// Month bar + the selected month's summary card and rows, in one scroll view.
///
/// The rows are their own [SliverList] rather than a Column of tiles: a Column
/// counts as one scroll child, so every tile in the month gets built and laid
/// out in the same frame the month changes. As a sliver only the on-screen tiles
/// are built, which is what keeps a heavy month switching as fast as a light one.
class _TransactionsList extends ConsumerStatefulWidget {
  const _TransactionsList({required this.isDark});
  final bool isDark;

  @override
  ConsumerState<_TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends ConsumerState<_TransactionsList> {
  /// Sign of the last month change: +1 forward, −1 back. Decides which side the
  /// card enters from. Stays here rather than in provider state because it is
  /// purely a view concern.
  double _direction = 1;

  /// The month key this widget last rendered, so the direction can be derived
  /// from consecutive builds. Comparing here (rather than in a `ref.listen`
  /// callback) keeps the direction correct regardless of notification ordering;
  /// it sets no state and triggers no rebuild.
  int? _lastKey;

  @override
  Widget build(BuildContext context) {
    final updatedAt = ref.watch(transactionsUpdatedAtProvider);
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(selectedMonthSummaryProvider);
    final txs = ref.watch(selectedMonthTransactionsProvider);

    // Same `year * 100 + month` convention as MonthGroup.sortKey.
    final key = month.year * 100 + month.month;
    if (_lastKey != null && key != _lastKey) {
      _direction = key > _lastKey! ? 1 : -1;
    }
    _lastKey = key;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(
            children: [
              UpdatedAtLabel(updatedAt: updatedAt, isDark: widget.isDark),
              _MonthBar(isDark: widget.isDark),
              const SizedBox(height: 4),
              // The card's height changes with the number of category bars
              // (0–5), so animate the height too or the slide ends in a snap.
              AnimatedSize(
                duration: _kMonthTransition,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: _kMonthTransition,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: _topAlignedSwitcherLayout,
                  transitionBuilder: (child, animation) =>
                      _slide(child, animation, key),
                  child: _SummaryHeader(
                    key: ValueKey(key),
                    summary: summary,
                    isDark: widget.isDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: txs.isEmpty
              ? SliverToBoxAdapter(
                  child: _MonthEmptyNotice(
                    month: month,
                    isDark: widget.isDark,
                  ),
                )
              : SliverList.builder(
                  itemCount: txs.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TransactionTile(
                      tx: txs[i],
                      isDark: widget.isDark,
                    ),
                  ),
                ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  /// AnimatedSwitcher runs the outgoing child's animation in reverse, so a
  /// single tween would send both children the same way. Testing each child's
  /// key against the current month is what makes the incoming card enter from
  /// one side while the outgoing card leaves from the other.
  Widget _slide(Widget child, Animation<double> animation, int currentKey) {
    final isIncoming = (child.key as ValueKey<int>).value == currentKey;
    final dx = (isIncoming ? _direction : -_direction) * _kSlideExtent;
    return SlideTransition(
      position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

/// Static ◀ / "July 2026" / ▶ bar. Deliberately outside the animated section:
/// a control that slid away with the content it drives would be untappable
/// mid-flight. Arrows go null-onPressed at the edges of the data, which renders
/// them disabled.
class _MonthBar extends ConsumerWidget {
  const _MonthBar({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final nav = ref.watch(monthNavProvider);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous month',
          onPressed: nav.canGoBack
              ? () => ref.read(selectedMonthProvider.notifier).shift(-1)
              : null,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color:
                  isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next month',
          onPressed: nav.canGoForward
              ? () => ref.read(selectedMonthProvider.notifier).shift(1)
              : null,
        ),
      ],
    );
  }
}

/// Shown in place of rows for a month that has none. The month bar stays put
/// above it, so this is never a dead end.
class _MonthEmptyNotice extends StatelessWidget {
  const _MonthEmptyNotice({required this.month, required this.isDark});
  final DateTime month;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        'No transactions in ${DateFormat('MMMM yyyy').format(month)}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: isDark
              ? AppColors.textTertiary
              : AppColors.textTertiaryLight,
        ),
      ),
    );
  }
}

/// One month's overview: spending, net invested, and a category breakdown.
/// Carries no month label of its own — that lives in the static [_MonthBar],
/// since this whole card slides out of view on a month change.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    super.key,
    required this.summary,
    required this.isDark,
  });
  final TransactionSummary summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final netIsNegative = summary.netInvested < 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Spending',
                  value: _num(summary.totalSpending),
                  valueColor: AppColors.negative,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(
                  label: 'Net invested',
                  value: _num(summary.netInvested),
                  valueColor:
                      netIsNegative ? AppColors.warning : AppColors.positive,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (summary.spendingByCategory.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Spending by category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textTertiary
                    : AppColors.textTertiaryLight,
              ),
            ),
            const SizedBox(height: 10),
            for (final cs in summary.spendingByCategory) ...[
              _CategoryBar(spending: cs, isDark: isDark),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Label + proportional bar + amount for one category's share of spending.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.spending, required this.isDark});
  final CategorySpending spending;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cat = spending.category;
    final color = cat.color;
    final trackColor =
        isDark ? AppColors.darkBorder : AppColors.surfaceContainerLow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(cat.icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                cat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _num(spending.amount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, color: trackColor),
              FractionallySizedBox(
                widthFactor: spending.fraction.clamp(0.0, 1.0),
                child: Container(height: 6, color: color),
              ),
            ],
          ),
        ),
      ],
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
