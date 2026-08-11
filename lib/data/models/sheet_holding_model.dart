import '../../domain/entities/sheet_holding.dart';

/// Maps the raw `Holdings` grid (the 2-D array returned by the Apps Script
/// `?sheet=` endpoint) into [SheetHolding]s.
///
/// Values are located by ANCHORING ON THE HEADER TEXT rather than fixed column
/// letters: find the `Symbol` header cell, then find the others in that same
/// header row. The tab is currently laid out with `Symbol` in column B through
/// `Currency` in column J, but anchoring means whatever sits in column A is
/// irrelevant and inserting a column cannot silently shift the mapping.
///
/// The tab's `Percentage` column is deliberately **not** read. It holds
/// `(Market Value − Base Value) / Base Value`, which [SheetHolding.returnFraction]
/// derives — same number, one fewer header to break on, and the derived version
/// can guard a zero cost basis.
abstract final class SheetHoldingModel {
  /// Tab name this model reads. Passed as `?sheet=` by the repository.
  static const String sheetName = 'Holdings';

  /// The one header that gates the parse; without it there is nothing to map.
  static const String symbolHeader = 'Symbol';

  static const String _quantityHeader = 'Quantity';
  static const String _avgPriceHeader = 'Avg Price';
  static const String _currentPriceHeader = 'Current Price';
  static const String _baseValueHeader = 'Base Value';
  static const String _marketValueHeader = 'Market Value';
  static const String _unrealizedGainHeader = 'Unrealized Gain';
  static const String _currencyHeader = 'Currency';

  /// The tab's positions, or **null when the `Symbol` header is absent** —
  /// which the repository reports as a Failure rather than an empty list.
  /// Unlike the `Accounts` tab, this one *is* the page, so "no rows" and "the
  /// wrong tab" must not look the same.
  ///
  /// Every other header is optional and yields nulls, so a sheet that is
  /// missing a column still lists its positions.
  static List<SheetHolding>? fromGrid(List<List<dynamic>> grid) {
    final symbolLoc = _find(grid, symbolHeader);
    if (symbolLoc == null) return null;
    final (headerRow, symbolCol) = symbolLoc;

    final header = grid[headerRow];
    final quantityCol = _findInRow(header, _quantityHeader);
    final avgPriceCol = _findInRow(header, _avgPriceHeader);
    final currentPriceCol = _findInRow(header, _currentPriceHeader);
    final baseValueCol = _findInRow(header, _baseValueHeader);
    final marketValueCol = _findInRow(header, _marketValueHeader);
    final gainCol = _findInRow(header, _unrealizedGainHeader);
    final currencyCol = _findInRow(header, _currencyHeader);

    double? cell(int r, int? c) => c == null ? null : _number(_at(grid, r, c));

    final holdings = <SheetHolding>[];
    for (var r = headerRow + 1; r < grid.length; r++) {
      final symbol = _text(_at(grid, r, symbolCol));
      if (symbol.isEmpty) continue;
      holdings.add(SheetHolding(
        symbol: symbol,
        currency: currencyCol == null
            ? ''
            : _text(_at(grid, r, currencyCol)).toUpperCase(),
        quantity: cell(r, quantityCol),
        avgPrice: cell(r, avgPriceCol),
        currentPrice: cell(r, currentPriceCol),
        baseValue: cell(r, baseValueCol),
        marketValue: cell(r, marketValueCol),
        unrealizedGain: cell(r, gainCol),
      ));
    }
    return holdings;
  }

  /// First (row, col) whose trimmed string value equals [label]; null if none.
  static (int, int)? _find(List<List<dynamic>> grid, String label) {
    for (var r = 0; r < grid.length; r++) {
      final col = _findInRow(grid[r], label);
      if (col != null) return (r, col);
    }
    return null;
  }

  static int? _findInRow(List<dynamic> row, String label) {
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      if (v is String && v.trim() == label) return c;
    }
    return null;
  }

  static dynamic _at(List<List<dynamic>> grid, int r, int c) {
    if (r < 0 || r >= grid.length) return null;
    final row = grid[r];
    if (c < 0 || c >= row.length) return null;
    return row[c];
  }

  static String _text(dynamic v) => v == null ? '' : v.toString().trim();

  /// A numeric cell, or null when it is blank or does not read as a number.
  /// Apps Script serializes numeric cells as real numbers; the string branch
  /// covers a value typed or pasted as text ('$1,234.50').
  static double? _number(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is! String) return null;
    final digits = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return digits.isEmpty ? null : double.tryParse(digits);
  }
}
