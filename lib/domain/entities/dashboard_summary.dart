/// A single point in the USD/KRW exchange-rate history.
class FxPoint {
  const FxPoint({required this.date, required this.rate});

  final DateTime date;

  /// USD→KRW close for [date].
  final double rate;
}

/// Pre-computed portfolio snapshot read from the sheet's `DashboardDB1` tab.
///
/// Pure Dart — no Flutter imports. Every figure here is authored by the
/// spreadsheet itself; the app only displays it, so the numbers always match
/// the user's Google Sheet dashboard rather than being recomputed client-side.
///
/// Currency-specific fields state their unit in their doc comment. The
/// cross-currency totals (cash / stocks / assets / invested) expose both a USD
/// and a KRW figure, exactly as the sheet does.
class DashboardSummary {
  const DashboardSummary({
    required this.exchangeRate,
    required this.usdCash,
    required this.krwCash,
    required this.usStocksUsd,
    required this.krStocksKrw,
    required this.totalCashUsd,
    required this.totalCashKrw,
    required this.totalStocksUsd,
    required this.totalStocksKrw,
    required this.totalAssetsUsd,
    required this.totalAssetsKrw,
    required this.usdInvested,
    required this.krwInvested,
    required this.totalInvestedUsd,
    required this.totalInvestedKrw,
    required this.returnRate,
    required this.fxHistory,
  });

  /// 환율 — USD→KRW rate.
  final double exchangeRate;

  /// 보유 USD 현금 (USD).
  final double usdCash;

  /// 보유 KRW 현금 (KRW).
  final double krwCash;

  /// 보유 미국 주식 (USD).
  final double usStocksUsd;

  /// 보유 한국 주식 (KRW).
  final double krStocksKrw;

  /// 총 보유 현금 — all cash, in USD / KRW.
  final double totalCashUsd;
  final double totalCashKrw;

  /// 총 보유 주식 — all stocks, in USD / KRW.
  final double totalStocksUsd;
  final double totalStocksKrw;

  /// 총 자산 — net worth as the sheet defines it (cash + stocks), USD / KRW.
  final double totalAssetsUsd;
  final double totalAssetsKrw;

  /// USD 투자 금액 (USD) / KRW 투자 금액 (KRW) — cost basis by market.
  final double usdInvested;
  final double krwInvested;

  /// 총 투자 금액 — total cost basis, USD / KRW.
  final double totalInvestedUsd;
  final double totalInvestedKrw;

  /// 총 수익률 as a fraction (0.2865 = +28.65%).
  final double returnRate;

  /// Daily USD/KRW close history, oldest → newest.
  final List<FxPoint> fxHistory;
}
