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

  static SheetTransaction fromJson(Map<String, dynamic> json) {
    // The live sheet returns capitalized header keys (`Date`, `Account`, …)
    // and names the ticker column `Symbol`. Build a case-insensitive index
    // once per row so lookups are robust to key casing.
    final lower = _lowerKeyIndex(json);

    final category = lower['category'];
    return SheetTransaction(
      date: _parseDate(lower['date']),
      account: (lower['account'] ?? '').toString(),
      type: TransactionTypeX.fromSheet(lower['type']?.toString()),
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
  /// A Purchase produces exactly one row (implemented below as the worked
  /// example). Buy/Sell row composition is intentionally a PLACEHOLDER — the
  /// real logic (e.g. whether to also write a companion cash-transfer leg) is
  /// to be wired up later. See [_tradeRowsPlaceholder].
  static List<List<dynamic>> toRows(SheetTransaction tx) {
    if (tx.type == TransactionType.purchase) {
      return [
        [
          tx.date.toIso8601String(),
          tx.account,
          tx.type.sheetValue,
          tx.category?.name ?? '',
          tx.description,
          '', // ticker
          '', // quantity
          '', // price
          tx.computedAmount,
        ],
      ];
    }
    return _tradeRowsPlaceholder(tx);
  }

  /// PLACEHOLDER for Buy/Sell row composition.
  ///
  /// TODO(jibsaja): replace with the real trade-row logic. For now this emits a
  /// single straightforward trade row so the feature is end-to-end functional;
  /// swap this out when the final sheet format / companion-row behavior is
  /// decided.
  static List<List<dynamic>> _tradeRowsPlaceholder(SheetTransaction tx) {
    return [
      [
        tx.date.toIso8601String(),
        tx.account,
        tx.type.sheetValue,
        '', // category
        tx.description,
        tx.ticker ?? '',
        tx.quantity ?? '',
        tx.price ?? '',
        tx.computedAmount,
      ],
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
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
