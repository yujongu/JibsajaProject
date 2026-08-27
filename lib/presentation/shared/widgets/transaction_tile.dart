import 'dart:math' as math;

import 'package:flutter/material.dart';
// intl exports its own TextDirection, which would shadow dart:ui's and break
// the TextPainter below; only DateFormat is needed here.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../domain/entities/sheet_transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_type.dart';
import '../../extensions/transaction_category_ui.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';

/// Breathing room on each side of the identity block's label.
const double _blockPad = 8;

/// The block never takes more than this share of the screen, however large the
/// platform text scale gets. Past it the label ellipsizes and the description
/// keeps its room.
const double _blockMaxShare = 0.30;

/// Same idea for the amount, which is not a flex child and would otherwise take
/// the whole row at an accessibility text scale.
const double _amountMaxShare = 0.34;

/// How far the label's colour is mixed toward the theme's text colour.
///
/// The label sits on a block washed in its own hue, so drawing it in that same
/// hue costs most of its contrast — across the eighteen labels that can be
/// drawn it ranged from 1.73:1 (Sell, light) to 4.2:1. At this mix the worst
/// case is 4.20:1 light (Sell) / 5.94:1 dark (Monthly), about WCAG AA for text
/// this size, and each label still reads as its own category's colour. The icon
/// keeps the pure hue.
const double _labelInkMix = 0.45;

/// How much of the category hue washes over the card, and over the deeper
/// identity block.
///
/// The two themes are tuned separately rather than sharing one pair. Light sits
/// at the heavier step: a wash over white has to be strong before it reads as a
/// colour at all. Dark sits a step lower — the same strength over the navy card
/// turned the rows into slabs of colour on a device, where in the mockups it had
/// looked right.
const double _bodyAlphaLight = 0.15;
const double _bodyAlphaDark = 0.15;
const double _blockAlphaLight = 0.28;
const double _blockAlphaDark = 0.26;

/// Every label the identity block can hold: the twelve sheet categories, plus
/// the types that reach it. Purchase never does — an expense shows its
/// category. Nor does [TransactionType.unknown]: that row renders the sheet's
/// own wording, which can be any length, so it is deliberately left out and
/// ellipsizes inside the block rather than widening every row of the month.
final List<String> _blockLabels = [
  for (final c in TransactionCategory.values) c.sheetValue.toUpperCase(),
  for (final t in TransactionType.values)
    if (t != TransactionType.purchase && t != TransactionType.unknown)
      t.label.toUpperCase(),
];

({TextScaler scaler, TextStyle style, double width})? _blockWidthMemo;

/// Drops the memo. Registered against [PaintingBinding.systemFonts] below, and
/// exposed so tests do not inherit each other's measurement.
@visibleForTesting
void resetBlockWidthCache() => _blockWidthMemo = null;

/// Inter is fetched over the network by `google_fonts` — nothing is bundled —
/// so the first measurements run against a fallback face with different
/// metrics. When the real font lands every text re-lays-out, but the memo would
/// keep serving the fallback's width for the rest of the process, leaving the
/// block permanently too narrow or too wide. One listener, installed once.
var _fontListenerInstalled = false;

void _watchSystemFonts() {
  if (_fontListenerInstalled) return;
  _fontListenerInstalled = true;
  PaintingBinding.instance.systemFonts.addListener(resetBlockWidthCache);
}

/// Width of the identity block: the widest label in [_blockLabels] laid out at
/// the current text scale, plus [_blockPad] on each side.
///
/// Measuring the whole set rather than the row's own label is what keeps every
/// block on screen the same width, so the edge between block and description
/// stays a straight line to scan down. Measuring rather than hard-coding a
/// width is what makes it follow the platform's text-size setting instead of
/// clipping when the user raises it.
///
/// Sixteen text layouts per text-scale change, memoized — not per row, per
/// frame. The sliver builder is the hot path.
///
/// [style] must be the colour-free metrics style: colour is the only part that
/// varies per row and it does not affect layout, so keying the memo on the
/// whole [TextStyle] (which has value equality) covers weight, letter-spacing
/// and family without listing them by hand.
double _measuredBlockWidth(TextScaler scaler, TextStyle style) {
  _watchSystemFonts();
  final memo = _blockWidthMemo;
  if (memo != null && memo.scaler == scaler && memo.style == style) {
    return memo.width;
  }

  var widest = 0.0;
  for (final label in _blockLabels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    widest = math.max(widest, painter.width);
  }

  final width = widest + 2 * _blockPad;
  _blockWidthMemo = (scaler: scaler, style: style, width: width);
  return width;
}

Color _wash(Color hue, Color surface, double alpha) =>
    Color.alphaBlend(hue.withValues(alpha: alpha), surface);

/// One row in a transaction list: a category-tinted card split into a deeper
/// identity block (icon over label) and the description, account, date and
/// amount. The block is what makes the category readable as *words* — before
/// it, the row said only "Purchase" and left hue and glyph to carry which
/// category it was.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    required this.isDark,
    this.currency,
    this.showIdentity = true,
  });
  final SheetTransaction tx;
  final bool isDark;

  /// Whether to draw the identity block.
  ///
  /// False on a list already filtered to one category, where every row's block
  /// would be the same icon and the same word — a fact the page states twice
  /// above the list. The card keeps its tint; the description gets the room the
  /// block would have taken.
  final bool showIdentity;

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
    final hue = isPurchase
        ? (cat ?? TransactionCategory.misc).color(isDark)
        : _typeColor(tx.type, isDark);

    // The block names the category for an expense and the type for everything
    // else — non-expense rows carry no Category column at all. An unrecognized
    // row is labelled with the sheet's own wording.
    final label = isPurchase
        ? (cat ?? TransactionCategory.misc).label
        : (tx.rawType ?? tx.type.label);

    // A purchase takes its category's glyph, like it takes its category's hue.
    final icon = isPurchase && cat != null ? cat.icon : _typeIcon(tx.type);

    final title = _title(cat);

    final card = isDark ? AppColors.darkCard : AppColors.surfaceCard;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondary
        : AppColors.textSecondaryLight;

    // Built from the ambient default so the label is measured in the same face
    // it is drawn in — the theme sets Inter, and a TextPainter that assumed the
    // platform default would size the block for the wrong font. Colour is added
    // separately: it is the only part that varies per row, and leaving it out
    // here is what lets the memo key on the style itself.
    final metricsStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      height: 1.2,
    );
    final labelStyle = metricsStyle.copyWith(
      color: Color.alphaBlend(textPrimary.withValues(alpha: _labelInkMix), hue),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Both caps are shares of the card, which is narrower than the screen
        // wherever the list pads its rows — and is the only correct basis if
        // this tile ever lands in a pane or dialog.
        final cardWidth = constraints.maxWidth;
        final blockWidth = showIdentity
            ? math.min(
                _measuredBlockWidth(
                  MediaQuery.textScalerOf(context),
                  metricsStyle,
                ),
                cardWidth * _blockMaxShare,
              )
            : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: _wash(hue, card, isDark ? _bodyAlphaDark : _bodyAlphaLight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              // The block's ground, painted to the row's full height so the
              // step between the two tints is one hard vertical edge. A
              // positioned fill rather than a stretched Row child keeps the
              // tile out of IntrinsicHeight, which the sliver builder would
              // pay for per row. Directional, so it tracks the Row beside it
              // rather than always hugging the physical left edge; its own
              // rounded start corners are what let the card drop its clip.
              if (showIdentity)
                PositionedDirectional(
                  key: const ValueKey('block-ground'),
                  top: 0,
                  bottom: 0,
                  start: 0,
                  width: blockWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _wash(
                        hue,
                        card,
                        isDark ? _blockAlphaDark : _blockAlphaLight,
                      ),
                      borderRadius: const BorderRadiusDirectional.horizontal(
                        start: Radius.circular(14),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  if (showIdentity)
                    SizedBox(
                      width: blockWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _blockPad,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 20, color: hue),
                            const SizedBox(height: 4),
                            Text(
                              label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: labelStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        showIdentity ? 13 : 14,
                        12,
                        10,
                        12,
                      ),
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
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 13, 12),
                    // Not a flex child, so without a cap it takes its full
                    // intrinsic width and — at an accessibility text scale, where
                    // that is most of the row — starves the description to
                    // nothing. Bounded and ellipsized, like the two lines beside
                    // it, so the description always keeps its share.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardWidth * _amountMaxShare,
                      ),
                      child: Text(
                        money(tx.computedAmount, currency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// What the row leads with: the description, or the best stand-in the sheet
  /// gives us when it is blank.
  String _title(TransactionCategory? cat) => switch (tx.type) {
    TransactionType.purchase =>
      tx.description.isNotEmpty ? tx.description : (cat?.label ?? 'Purchase'),
    // Transfer rows carry no ticker; show their note (the trade description).
    TransactionType.transfer =>
      tx.description.isNotEmpty ? tx.description : 'Transfer',
    TransactionType.deposit =>
      tx.description.isNotEmpty ? tx.description : 'Deposit',
    TransactionType.unknown =>
      tx.description.isNotEmpty
          ? tx.description
          : (tx.rawType ?? tx.type.label),
    _ => tx.ticker ?? tx.type.label,
  };

  /// "BoA · Aug 24, 2026", plus quantity @ price on the rows that carry one.
  String get _subtitle => [
    tx.account,
    DateFormat('MMM d, yyyy').format(tx.date),
    if (tx.type != TransactionType.purchase &&
        tx.quantity != null &&
        tx.price != null)
      '${plainNumber(tx.quantity!)} @ ${plainNumber(tx.price!)}',
  ].join(' · ');
}

/// The five type colors, as light/dark pairs like the twelve category hues
/// already are. The dark value is the lighter of each pair — a single constant
/// left Buy and Deposit sitting almost unreadably dark on the navy card.
/// The type glyphs, as the theme-independent counterpart to [_typeColor]. The
/// purchase entry is only reached by an expense the sheet left uncategorized —
/// a categorized one draws its category's icon.
IconData _typeIcon(TransactionType t) => switch (t) {
  TransactionType.purchase => Icons.shopping_bag_rounded,
  TransactionType.buy => Icons.trending_up_rounded,
  TransactionType.sell => Icons.trending_down_rounded,
  TransactionType.transfer => Icons.swap_horiz_rounded,
  TransactionType.deposit => Icons.arrow_downward_rounded,
  TransactionType.unknown => Icons.help_outline_rounded,
};

Color _typeColor(TransactionType t, bool isDark) {
  switch (t) {
    case TransactionType.purchase:
      return isDark ? const Color(0xFFF87171) : AppColors.negative;
    case TransactionType.buy:
      return isDark ? AppColors.primaryMuted : AppColors.primary;
    case TransactionType.sell:
      return AppColors.warning; // amber-500 reads on both grounds
    case TransactionType.transfer:
      return isDark ? const Color(0xFF22D3EE) : AppColors.secondaryFallback;
    case TransactionType.deposit:
      return isDark ? const Color(0xFF34D399) : AppColors.positive;
    case TransactionType.unknown:
      return isDark ? AppColors.textSecondary : AppColors.textTertiaryLight;
  }
}
