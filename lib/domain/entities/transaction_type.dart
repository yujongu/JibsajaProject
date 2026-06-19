/// The three kinds of rows the app can add to the transactions sheet.
/// - [purchase]: a cash expense (amount + category + description).
/// - [buy] / [sell]: an asset trade (ticker + quantity + price).
enum TransactionType { purchase, buy, sell }

extension TransactionTypeX on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.purchase: return 'Purchase';
      case TransactionType.buy:      return 'Buy';
      case TransactionType.sell:     return 'Sell';
    }
  }

  /// Wire value written to the sheet's `Type` column.
  String get sheetValue {
    switch (this) {
      case TransactionType.purchase: return 'Purchase';
      case TransactionType.buy:      return 'Buy';
      case TransactionType.sell:     return 'Sell';
    }
  }

  bool get isTrade =>
      this == TransactionType.buy || this == TransactionType.sell;

  /// Parse the sheet's `Type` column back into an enum. Unknown values
  /// fall back to [purchase] so the viewer never crashes on bad data.
  static TransactionType fromSheet(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'buy':  return TransactionType.buy;
      case 'sell': return TransactionType.sell;
      default:     return TransactionType.purchase;
    }
  }
}
