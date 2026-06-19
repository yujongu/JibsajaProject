enum TransactionCategory {
  // Expense
  food,
  transport,
  shopping,
  health,
  entertainment,
  housing,
  education,
  utilities,
  investment,
  other,
}

extension TransactionCategoryX on TransactionCategory {
  String get label {
    switch (this) {
      case TransactionCategory.food:          return 'Food';
      case TransactionCategory.transport:     return 'Transport';
      case TransactionCategory.shopping:      return 'Shopping';
      case TransactionCategory.health:        return 'Health';
      case TransactionCategory.entertainment: return 'Entertainment';
      case TransactionCategory.housing:       return 'Housing';
      case TransactionCategory.education:     return 'Education';
      case TransactionCategory.utilities:     return 'Utilities';
      case TransactionCategory.investment:    return 'Investment';
      case TransactionCategory.other:         return 'Other';
    }
  }

  /// Parse the sheet's `Category` column back into an enum.
  static TransactionCategory fromSheet(String? raw) {
    final v = raw?.trim().toLowerCase();
    return TransactionCategory.values.firstWhere(
      (c) => c.name == v,
      orElse: () => TransactionCategory.other,
    );
  }
}
