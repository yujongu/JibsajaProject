/// The kinds of rows that live in the transactions sheet.
/// - [purchase]: a cash expense (amount + category + description).
/// - [buy] / [sell]: an asset trade (ticker + quantity + price). Writing one
///   also writes a companion [transfer] row for the cash leg.
/// - [transfer]: a cash movement. Two shapes exist in the sheet:
///   the generated cash leg of a Buy/Sell (signed **Amount**: negative =
///   cash out, positive = cash in), and a directly entered transfer — one
///   row whose value lives in the **Price** column (Quantity/Amount blank).
enum TransactionType {
  purchase,
  buy,
  sell,
  transfer,

  /// Read-only: cash in, entered directly in the sheet. Never written by the app.
  deposit,

  /// Read-only fallback for a `Type` value the app does not recognize.
  unknown;

  /// The types the user can pick in the add-transaction form.
  static const userSelectable = [purchase, buy, sell, transfer];
}

extension TransactionTypeX on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.purchase: return 'Purchase';
      case TransactionType.buy:      return 'Buy';
      case TransactionType.sell:     return 'Sell';
      case TransactionType.transfer: return 'Transfer';
      case TransactionType.deposit:  return 'Deposit';
      case TransactionType.unknown:  return 'Other';
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
      case TransactionType.deposit:  return 'Deposit';
      // Not user-selectable, so never written. Throw rather than silently
      // append a row with a bogus Type.
      case TransactionType.unknown:
        throw UnsupportedError('TransactionType.unknown cannot be written');
    }
  }

  bool get isTrade =>
      this == TransactionType.buy || this == TransactionType.sell;

  /// Parse the sheet's `Type` column back into an enum. Every known value is
  /// matched explicitly — the stored `Expense` and the legacy `Purchase` both
  /// map to [purchase]. Anything else (typos, blank cells, types added to the
  /// sheet but not to the app) becomes [unknown] rather than masquerading as a
  /// purchase; the viewer renders it neutrally and leaves it out of totals.
  static TransactionType fromSheet(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'expense':
      case 'purchase': return TransactionType.purchase;
      case 'buy':      return TransactionType.buy;
      case 'sell':     return TransactionType.sell;
      case 'transfer': return TransactionType.transfer;
      case 'deposit':  return TransactionType.deposit;
      default:         return TransactionType.unknown;
    }
  }
}
