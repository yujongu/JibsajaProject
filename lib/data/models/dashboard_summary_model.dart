import '../../domain/entities/dashboard_summary.dart';

/// Maps the raw `DashboardDB1` grid (the 2-D array returned by the Apps Script
/// `?sheet=` endpoint) into a [DashboardSummary].
///
/// Values are located by ANCHORING ON LABEL TEXT rather than fixed cell
/// coordinates: find the cell whose (trimmed) text equals a Korean label and
/// read the cell — or cells — to its right. This survives row/column inserts in
/// the sheet, which hardcoded `[4][4]`-style lookups would not.
abstract final class DashboardSummaryModel {
  /// Tab name this model reads. Passed as `?sheet=` by the repository.
  static const String sheetName = 'DashboardDB1';

  static DashboardSummary fromGrid(List<List<dynamic>> grid) {
    // Value in the cell [offset] columns to the right of [label], or 0.
    double right(String label, {int offset = 1}) {
      final loc = _find(grid, label);
      if (loc == null) return 0;
      return _toDouble(_at(grid, loc.$1, loc.$2 + offset));
    }

    return DashboardSummary(
      exchangeRate: right('환율'),
      usdCash: right('보유 USD 현금'),
      krwCash: right('보유 KRW 현금'),
      usStocksUsd: right('보유 미국 주식'),
      krStocksKrw: right('보유 한국 주식'),
      // Dual-currency rows: USD sits at +1, KRW at +2.
      totalCashUsd: right('총 보유 현금'),
      totalCashKrw: right('총 보유 현금', offset: 2),
      totalStocksUsd: right('총 보유 주식'),
      totalStocksKrw: right('총 보유 주식', offset: 2),
      totalAssetsUsd: right('총 자산'),
      totalAssetsKrw: right('총 자산', offset: 2),
      usdInvested: right('USD 투자 금액'),
      krwInvested: right('KRW 투자 금액'),
      totalInvestedUsd: right('총 투자 금액 (in USD)'),
      totalInvestedKrw: right('총 투자 금액 (in KRW)'),
      returnRate: right('총 수익률'),
      fxHistory: _parseFxHistory(grid),
    );
  }

  /// The daily USD/KRW series lives under the "Date"/"Close" header columns.
  /// Anchor on "Close", then read straight down: the date is one column to the
  /// left, the rate in the "Close" column itself.
  static List<FxPoint> _parseFxHistory(List<List<dynamic>> grid) {
    final header = _find(grid, 'Close');
    if (header == null) return const [];
    final (headerRow, rateCol) = header;
    final dateCol = rateCol - 1;

    final points = <FxPoint>[];
    for (var r = headerRow + 1; r < grid.length; r++) {
      final rawRate = _at(grid, r, rateCol);
      // Only genuine numbers — this skips blank rows and the stray cell that
      // the sheet serialises as a bogus "1904-..." date string.
      if (rawRate is! num) continue;
      final rawDate = _at(grid, r, dateCol);
      final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
      if (date == null) continue;
      points.add(FxPoint(date: date, rate: rawRate.toDouble()));
    }
    return points;
  }

  /// First (row, col) whose trimmed string value equals [label]; null if none.
  static (int, int)? _find(List<List<dynamic>> grid, String label) {
    for (var r = 0; r < grid.length; r++) {
      final row = grid[r];
      for (var c = 0; c < row.length; c++) {
        final v = row[c];
        if (v is String && v.trim() == label) return (r, c);
      }
    }
    return null;
  }

  static dynamic _at(List<List<dynamic>> grid, int r, int c) {
    if (r < 0 || r >= grid.length) return null;
    final row = grid[r];
    if (c < 0 || c >= row.length) return null;
    return row[c];
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
    return 0;
  }
}
