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
    this.ticker,
    this.quantity,
    this.price,
    this.amount,
  });

  final DateTime date;
  final String account;
  final TransactionType type;

  /// Expense category — only meaningful for [TransactionType.purchase].
  final TransactionCategory? category;
  final String description;

  // Trade-only fields (Buy / Sell).
  final String? ticker;
  final double? quantity;
  final double? price;

  /// Total value of the row.
  /// - Purchase: the expense amount.
  /// - Buy / Sell: quantity * price (the trade total).
  final double? amount;

  /// Convenience for trade rows when [amount] is not explicitly set.
  double get computedAmount =>
      amount ?? ((quantity ?? 0) * (price ?? 0));
}
