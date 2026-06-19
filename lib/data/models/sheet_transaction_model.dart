import '../../domain/entities/sheet_transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_type.dart';

/// Maps a [SheetTransaction] to/from the Google Sheet.
///
/// ## Sheet column layout (transactions tab)
/// | 0 Date | 1 Account | 2 Type | 3 Category | 4 Description | 5 Ticker |
/// | 6 Quantity | 7 Price | 8 Amount | 9 Id |
///
/// The GET endpoint of the Apps Script web app is expected to return:
/// `{ "rows": [ { "date":..., "account":..., "type":..., "category":...,
///   "description":..., "ticker":..., "quantity":..., "price":...,
///   "amount":... }, ... ] }`
/// (object-per-row keeps parsing resilient to column reordering).
abstract final class SheetTransactionModel {
  /// Column order used when appending rows via the POST endpoint.
  static const List<String> columns = [
    'date',
    'account',
    'type',
    'category',
    'description',
    'ticker',
    'quantity',
    'price',
    'amount',
  ];

  // ── Reading (GET) ──────────────────────────────────────────────────────────

  static SheetTransaction fromJson(Map<String, dynamic> json) {
    return SheetTransaction(
      date: _parseDate(json['date']),
      account: (json['account'] ?? '').toString(),
      type: TransactionTypeX.fromSheet(json['type']?.toString()),
      category: json['category'] == null || json['category'].toString().isEmpty
          ? null
          : TransactionCategoryX.fromSheet(json['category'].toString()),
      description: (json['description'] ?? '').toString(),
      ticker: _emptyToNull(json['ticker']),
      quantity: _parseNum(json['quantity']),
      price: _parseNum(json['price']),
      amount: _parseNum(json['amount']),
    );
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
