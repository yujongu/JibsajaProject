/// One row of the sheet's `Holdings` tab — a stock position as the spreadsheet
/// currently values it.
///
/// Pure Dart — no Flutter/HTTP imports. Read-only: the app never writes to the
/// `Holdings` tab.
class SheetHolding {
  const SheetHolding({
    required this.symbol,
    this.name,
    this.currency = '',
    this.quantity,
    this.avgPrice,
    this.currentPrice,
    this.baseValue,
    this.marketValue,
    this.unrealizedGain,
  });

  /// The ticker as written in the sheet ('NVDA', '삼성전자').
  final String symbol;

  /// The company/stock name from the sheet's Name column (column A), or null
  /// when that cell is blank.
  final String? name;

  /// ISO code from the sheet's Currency cell ('KRW', 'USD'), or empty when the
  /// cell is blank — an unknown currency renders as a bare, unlabelled amount.
  final String currency;

  /// Shares held, the average price paid, and the latest price the sheet knows.
  ///
  /// Null means the cell was blank or unparseable — distinct from 0, which is a
  /// real value (a fully-sold position). Nothing here is defaulted to zero: a
  /// blank cell must not be able to look like real data.
  final double? quantity;
  final double? avgPrice;
  final double? currentPrice;

  /// Cost basis and current worth, straight from the sheet's own columns rather
  /// than recomputed from [quantity] — the spreadsheet is the authority.
  final double? baseValue;
  final double? marketValue;

  /// The sheet's Unrealized Gain cell, **signed exactly as it stores it**.
  final double? unrealizedGain;

  /// Whether this position can take part in a section's totals. Both halves of
  /// the sum must be known, so that `market − cost == gain` always holds for
  /// the totals the header shows.
  bool get isValued => marketValue != null && baseValue != null;

  /// Unrealized gain as a fraction of cost — the sheet's `Percentage` column,
  /// derived rather than read.
  ///
  /// Null when either input is missing, and when the cost basis is zero: a
  /// position that cost nothing has no meaningful return, and dividing would
  /// import the spreadsheet's own `#DIV/0!`.
  double? get returnFraction {
    final cost = baseValue;
    final gain = unrealizedGain;
    if (cost == null || gain == null || cost == 0) return null;
    return gain / cost;
  }
}

/// Which column the Holdings list is ordered by.
enum HoldingSort { symbol, value, gain, gainPercent }

enum SortDir { asc, desc }

/// The Holdings list's ordering: a column plus a direction.
typedef HoldingOrder = ({HoldingSort field, SortDir dir});

extension HoldingSortDefaults on HoldingSort {
  /// The direction this column takes the first time it is tapped: names read
  /// A→Z, numbers read biggest-first. Re-tapping the active column is what
  /// reverses it.
  SortDir get naturalDir =>
      this == HoldingSort.symbol ? SortDir.asc : SortDir.desc;
}

/// One currency's positions and totals.
///
/// No conversion happens anywhere — the app takes no FX feed, so KRW and USD
/// positions are never added together. Same rule the transaction summary
/// follows.
class CurrencyHoldings {
  const CurrencyHoldings({
    required this.currency,
    required this.holdings,
    required this.marketValue,
    required this.baseValue,
  });

  /// ISO code ('KRW', 'USD'), or null when the sheet's Currency cell was blank
  /// for these rows — the amounts then render unlabelled.
  final String? currency;

  /// Every position in this currency, already in the requested order.
  /// Includes rows that are not [SheetHolding.isValued]; those are listed but
  /// contribute nothing to the totals below.
  final List<SheetHolding> holdings;

  /// Σ of the valued rows' market values and cost bases.
  final double marketValue;
  final double baseValue;

  double get unrealizedGain => marketValue - baseValue;

  /// Return on this currency's positions, or null when nothing cost anything.
  double? get returnFraction =>
      baseValue == 0 ? null : unrealizedGain / baseValue;

  /// [h]'s share of this currency's market value, 0–1. Zero for a position the
  /// totals exclude, so an unvalued row gets no bar rather than a wrong one.
  double share(SheetHolding h) {
    if (marketValue == 0 || !h.isValued) return 0;
    return h.marketValue! / marketValue;
  }
}

extension SheetHoldingList on List<SheetHolding> {
  /// The positions whose Currency cell is one of [codes], compared case- and
  /// whitespace-insensitively so `' usd '` in the sheet still matches. [codes]
  /// must already be upper-case.
  ///
  /// A **blank** Currency cell matches nothing, so an unlabelled position is
  /// filtered out rather than kept as a catch-all.
  List<SheetHolding> inCurrencies(Set<String> codes) => [
        for (final h in this)
          if (codes.contains(h.currency.trim().toUpperCase())) h,
      ];

  /// Positions grouped into one section per currency, each ordered by [order].
  ///
  /// Sections lead with the largest by market value; a blank-currency section
  /// always sorts last, since it is the "the sheet didn't say" bucket rather
  /// than a real currency.
  List<CurrencyHoldings> groupByCurrency(HoldingOrder order) {
    final buckets = <String, List<SheetHolding>>{};
    for (final h in this) {
      // Case- and whitespace-insensitive, so ' usd ' groups with 'USD'.
      buckets.putIfAbsent(h.currency.trim().toUpperCase(), () => []).add(h);
    }

    final sections = <CurrencyHoldings>[];
    for (final entry in buckets.entries) {
      var market = 0.0;
      var base = 0.0;
      for (final h in entry.value) {
        if (!h.isValued) continue;
        market += h.marketValue!;
        base += h.baseValue!;
      }
      sections.add(CurrencyHoldings(
        currency: entry.key.isEmpty ? null : entry.key,
        holdings: _ordered(entry.value, order),
        marketValue: market,
        baseValue: base,
      ));
    }

    sections.sort((a, b) {
      if ((a.currency == null) != (b.currency == null)) {
        return a.currency == null ? 1 : -1;
      }
      return b.marketValue.compareTo(a.marketValue);
    });
    return sections;
  }
}

/// The value [field] orders by, or null when this row has nothing to compare.
double? _sortKey(SheetHolding h, HoldingSort field) => switch (field) {
      HoldingSort.value => h.marketValue,
      HoldingSort.gain => h.unrealizedGain,
      HoldingSort.gainPercent => h.returnFraction,
      HoldingSort.symbol => null,
    };

int _bySymbol(SheetHolding a, SheetHolding b) =>
    a.symbol.toUpperCase().compareTo(b.symbol.toUpperCase());

List<SheetHolding> _ordered(List<SheetHolding> rows, HoldingOrder order) {
  final sign = order.dir == SortDir.desc ? -1 : 1;

  if (order.field == HoldingSort.symbol) {
    return [...rows]..sort((a, b) => sign * _bySymbol(a, b));
  }

  // Rows with nothing to compare go last in BOTH directions — reversing a list
  // that had them at one end would float them to the top, which is the one
  // ordering that is never useful. They keep a stable A–Z order among
  // themselves.
  final known = <SheetHolding>[];
  final absent = <SheetHolding>[];
  for (final h in rows) {
    (_sortKey(h, order.field) == null ? absent : known).add(h);
  }

  // Symbol breaks ties so equal values do not shuffle between rebuilds —
  // List.sort is not stable. The tiebreak stays A–Z in both directions,
  // because the sign is applied to the value comparison only.
  known.sort((a, b) {
    final byValue = _sortKey(a, order.field)!
        .compareTo(_sortKey(b, order.field)!);
    return byValue != 0 ? sign * byValue : _bySymbol(a, b);
  });
  absent.sort(_bySymbol);

  return [...known, ...absent];
}
