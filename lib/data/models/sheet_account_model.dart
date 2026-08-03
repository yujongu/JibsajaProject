import '../../domain/entities/sheet_account.dart';

/// Maps the raw `Accounts` grid (the 2-D array returned by the Apps Script
/// `?sheet=` endpoint) into [SheetAccount]s.
///
/// Values are located by ANCHORING ON THE HEADER TEXT rather than fixed column
/// letters: find the `Account Name` header cell, then find `Currency` in that
/// same header row. The tab is currently laid out as
/// `Account Name | Type | Institution | Currency | Include? | …`, but anchoring
/// means inserting a column does not silently shift the mapping.
abstract final class SheetAccountModel {
  /// Tab name this model reads. Passed as `?sheet=` by the repository.
  static const String sheetName = 'Accounts';

  static const String _nameHeader = 'Account Name';
  static const String _currencyHeader = 'Currency';

  static List<SheetAccount> fromGrid(List<List<dynamic>> grid) {
    final nameLoc = _find(grid, _nameHeader);
    if (nameLoc == null) return const [];
    final (headerRow, nameCol) = nameLoc;

    final currencyCol = _findInRow(grid[headerRow], _currencyHeader);
    if (currencyCol == null) return const [];

    final accounts = <SheetAccount>[];
    for (var r = headerRow + 1; r < grid.length; r++) {
      final name = _text(_at(grid, r, nameCol));
      if (name.isEmpty) continue;
      accounts.add(SheetAccount(
        name: name,
        currency: _text(_at(grid, r, currencyCol)).toUpperCase(),
      ));
    }
    return accounts;
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
}
