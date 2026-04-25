enum TransactionType { income, expense, buy, sell, transfer }

extension TransactionTypeX on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.income:   return 'Income';
      case TransactionType.expense:  return 'Expense';
      case TransactionType.buy:      return 'Buy';
      case TransactionType.sell:     return 'Sell';
      case TransactionType.transfer: return 'Transfer';
    }
  }

  bool get isTrade =>
      this == TransactionType.buy || this == TransactionType.sell;
}
