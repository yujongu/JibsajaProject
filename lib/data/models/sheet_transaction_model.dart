import '../../domain/entities/sheet_transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_type.dart';

/// Maps a [SheetTransaction] to/from the Google Sheet.
///
/// ## Sheet column layout (transactions tab)
/// | 0 Date | 1 Account | 2 Type | 3 Category | 4 Description | 5 Symbol |
/// | 6 Quantity | 7 Price | 8 Amount |
///
/// The GET endpoint of the Apps Script web app returns objects keyed by the
/// sheet's (capitalized) header names:
/// `{ "rows": [ { "Date":..., "Account":..., "Type":..., "Category":...,
///   "Description":..., "Symbol":..., "Quantity":..., "Price":...,
///   "Amount":... }, ... ] }`
/// (object-per-row keeps parsing resilient to column reordering).
///
/// Key lookup in [fromJson] is **case-insensitive**, so lowercase or
/// capitalized keys both parse. The ticker column is read from `Symbol`
/// (canonical) and falls back to `ticker` for compatibility.
abstract final class SheetTransactionModel {
  /// Column order used when appending rows via the POST endpoint.
  ///
  /// Note: these are the POST value-array positions (position-based, not the
  /// GET object keys). `symbol` here is the ticker column at index 5.
  static const List<String> columns = [
    'date',
    'account',
    'type',
    'category',
    'description',
    'symbol',
    'quantity',
    'price',
    'amount',
  ];

  // ── Reading (GET) ──────────────────────────────────────────────────────────

  static SheetTransaction fromJson(Map<String, dynamic> json,
      {int rowIndex = 0}) {
    // The live sheet returns capitalized header keys (`Date`, `Account`, …)
    // and names the ticker column `Symbol`. Build a case-insensitive index
    // once per row so lookups are robust to key casing.
    final lower = _lowerKeyIndex(json);

    final category = lower['category'];
    final rawType = lower['type']?.toString();
    final type = TransactionTypeX.fromSheet(rawType);
    return SheetTransaction(
      date: _parseDate(lower['date']),
      rowIndex: rowIndex,
      account: (lower['account'] ?? '').toString(),
      type: type,
      // Keep the sheet's own wording for a Type the app doesn't know, so the
      // row can be labelled with it instead of a generic fallback.
      rawType: type == TransactionType.unknown ? _emptyToNull(rawType) : null,
      category: category == null || category.toString().isEmpty
          ? null
          : TransactionCategoryX.fromSheet(category.toString()),
      description: (lower['description'] ?? '').toString(),
      // Canonical column is `Symbol`; fall back to `ticker` when Symbol is
      // absent or empty.
      ticker: _emptyToNull(lower['symbol']) ?? _emptyToNull(lower['ticker']),
      quantity: _parseNum(lower['quantity']),
      price: _parseNum(lower['price']),
      amount: _parseNum(lower['amount']),
    );
  }

  /// Builds a map of the row's keys lowercased, for case-insensitive lookups.
  ///
  /// If two keys collide once lowercased (unexpected for the sheet headers),
  /// the last one wins.
  static Map<String, dynamic> _lowerKeyIndex(Map<String, dynamic> json) {
    final out = <String, dynamic>{};
    for (final entry in json.entries) {
      out[entry.key.toLowerCase()] = entry.value;
    }
    return out;
  }

  // ── Writing (POST) ─────────────────────────────────────────────────────────

  /// Builds the row(s) to append for [tx], matching [columns].
  ///
  /// A Purchase produces exactly one `Expense` row whose Amount is stored
  /// **negative** (cash out) — the form passes the user's positive input and
  /// the sign is applied here. A Buy/Sell produces **two** rows — the cash
  /// Transfer leg plus the trade leg — see [_tradeRows]. A directly entered
  /// Transfer produces one row whose value lives in the **Amount** column,
  /// written as entered — Category, Symbol, Quantity and Price stay blank.
  static List<List<dynamic>> toRows(SheetTransaction tx) {
    if (tx.type.isTrade) return _tradeRows(tx);
    if (tx.type == TransactionType.transfer) {
      return [
        [
          tx.date.toIso8601String(),
          tx.account,
          tx.type.sheetValue,
          '', // category
          tx.description,
          '', // ticker
          '', // quantity
          '', // price
          tx.amount ?? '',
        ],
      ];
    }
    final isExpense = tx.type == TransactionType.purchase;
    return [
      [
        tx.date.toIso8601String(),
        tx.account,
        tx.type.sheetValue,
        tx.category?.sheetValue ?? '',
        tx.description,
        '', // ticker
        '', // quantity
        '', // price
        isExpense ? -tx.computedAmount : tx.computedAmount,
      ],
    ];
  }

  /// Double-entry composition for a trade: every Buy/Sell writes two rows so
  /// each account's balance stays the sum of its signed Amounts.
  ///
  /// | leg | Account | Type | Quantity | Amount |
  /// | :-- | :-- | :-- | :-- | :-- |
  /// | cash | [SheetTransaction.account] | Transfer | blank | Buy: −(qty × price), Sell: +(qty × price) |
  /// | trade | [SheetTransaction.secondAccount] | Buy / Sell | Buy: +qty, Sell: −qty | quantity × price |
  ///
  /// The sheet stores Sell quantities **negative**, so the trade leg's Amount
  /// is always plain quantity × price; the cash leg is its negation. The
  /// incoming [tx] carries the user's positive quantity — the sign is applied
  /// here.
  static List<List<dynamic>> _tradeRows(SheetTransaction tx) {
    final date = tx.date.toIso8601String();
    final isSell = tx.type == TransactionType.sell;
    final signedQty =
        tx.quantity == null ? null : (isSell ? -tx.quantity! : tx.quantity!);
    final tradeAmount = (signedQty ?? 0) * (tx.price ?? 0);
    return [
      [
        date,
        tx.account,
        TransactionType.transfer.sheetValue,
        '', // category
        tx.description,
        '', // ticker
        '', // quantity
        '', // price
        -tradeAmount,
      ],
      [
        date,
        tx.secondAccount ?? tx.account,
        tx.type.sheetValue,
        '', // category
        tx.description,
        tx.ticker ?? '',
        signedQty ?? '',
        tx.price ?? '',
        tradeAmount,
      ],
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Apps Script serializes date cells as UTC ISO strings (a KST `2026-02-01`
  /// arrives as `"2026-01-31T15:00:00.000Z"`), so convert to local time —
  /// otherwise day/month grouping and the displayed date shift back a day.
  /// App-written dates have no `Z` and parse as local already ([DateTime.toLocal]
  /// is a no-op for them).
  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString())?.toLocal() ?? DateTime.now();
  }

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static String? _emptyToNull(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
