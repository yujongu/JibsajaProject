/// The kinds of rows that live in the transactions sheet.
/// - [purchase]: a cash expense (amount + category + description).
/// - [buy] / [sell]: an asset trade (ticker + quantity + price). Writing one
///   also writes a companion [transfer] row for the cash leg.
/// - [transfer]: a cash movement between accounts. Never entered directly in
///   the app — it is generated as the cash leg of a Buy/Sell (signed amount:
///   negative = cash out, positive = cash in).
enum TransactionType {
  purchase,
  buy,
  sell,
  transfer;

  /// The types the user can pick in the add-transaction form. [transfer] is
  /// excluded — it only exists as the generated cash leg of a trade.
  static const userSelectable = [purchase, buy, sell];
}

extension TransactionTypeX on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.purchase: return 'Purchase';
      case TransactionType.buy:      return 'Buy';
      case TransactionType.sell:     return 'Sell';
      case TransactionType.transfer: return 'Transfer';
    }
  }

  /// Wire value written to the sheet's `Type` column. Note the app-side
  /// "Purchase" is stored as **`Expense`** in the sheet.
  String get sheetValue {
    switch (this) {
      case TransactionType.purchase: return 'Expense';
      case TransactionType.buy:      return 'Buy';
      case TransactionType.sell:     return 'Sell';
      case TransactionType.transfer: return 'Transfer';
    }
  }

  bool get isTrade =>
      this == TransactionType.buy || this == TransactionType.sell;

  /// Parse the sheet's `Type` column back into an enum. Unknown values
  /// (including the stored `Expense` and the legacy `Purchase`) fall back to
  /// [purchase] so the viewer never crashes on bad data.
  static TransactionType fromSheet(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'buy':      return TransactionType.buy;
      case 'sell':     return TransactionType.sell;
      case 'transfer': return TransactionType.transfer;
      default:         return TransactionType.purchase;
    }
  }
}
