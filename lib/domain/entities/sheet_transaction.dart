import 'transaction_category.dart';
import 'transaction_type.dart';

/// One transaction row as it lives in the Google Sheet.
///
/// Pure Dart — no Flutter/HTTP imports. The data layer maps this to/from the
/// sheet's column layout (see `SheetTransactionModel`).
class SheetTransaction {
  const SheetTransaction({
    required this.date,
    required this.account,
    required this.type,
    this.category,
    this.description = '',
    this.secondAccount,
    this.ticker,
    this.quantity,
    this.price,
    this.amount,
    this.rowIndex = 0,
    this.rawType,
  });

  /// Local-time transaction date. Sheet timestamps arrive as UTC ISO strings;
  /// the data layer converts them so day/month grouping matches the sheet.
  final DateTime date;

  /// The account this row belongs to. For a Buy/Sell being written, this is
  /// the **cash account** the money leaves (Buy) or lands in (Sell).
  final String account;
  final TransactionType type;

  /// Expense category — only meaningful for [TransactionType.purchase].
  final TransactionCategory? category;
  final String description;

  /// Write-only, Buy/Sell: the **brokerage account** holding the asset — the
  /// trade row is written against it while [account] gets the Transfer cash
  /// leg. Always null on rows read back from the sheet (each sheet row only
  /// has its own Account column).
  final String? secondAccount;

  // Trade-only fields (Buy / Sell).
  final String? ticker;

  /// Sheet rows store Sell quantities **negative** (so Amount is always
  /// quantity × price). The add-form passes the user's positive input; the
  /// data layer applies the sign when writing.
  final double? quantity;
  final double? price;

  /// Signed total value of the row, as stored in the sheet's Amount column.
  /// - Purchase/Expense: stored **negative** (cash out); the add-form passes
  ///   the user's positive input and the data layer applies the sign.
  /// - Buy / Sell: quantity × price (negative for Sell via its quantity).
  /// - Transfer: negative = cash out, positive = cash in.
  final double? amount;

  /// Position of this row in the sheet (0-based, top to bottom), used to keep
  /// a deterministic order between rows sharing the same [date]. 0 for
  /// app-composed transactions that were never read back.
  final int rowIndex;

  /// The sheet's raw `Type` cell, kept only when [type] is
  /// [TransactionType.unknown] so the UI can show what the sheet actually said.
  final String? rawType;

  /// Convenience for rows whose [amount] is not explicitly set: trades fall
  /// back to quantity × price. Directly entered Transfers now store their
  /// value in Amount; the Price fallback keeps **legacy** transfer rows
  /// (written before 2026-07-04 with the value in the Price column) readable.
  double get computedAmount {
    if (amount != null) return amount!;
    if (type == TransactionType.transfer) return price ?? 0;
    return (quantity ?? 0) * (price ?? 0);
  }

  /// Newest-first ordering: by [date], tie-broken by sheet position (later
  /// rows first). Dart's sort is unstable, so without the tiebreak rows with
  /// identical timestamps — same-day entries, the two legs of a trade —
  /// would shuffle arbitrarily between refreshes.
  static int newestFirst(SheetTransaction a, SheetTransaction b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.rowIndex.compareTo(a.rowIndex);
  }
}
