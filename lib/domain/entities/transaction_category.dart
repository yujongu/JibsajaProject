import 'transaction_type.dart';

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
  // Income
  salary,
  freelance,
  investment,
  gift,
  // Shared
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
      case TransactionCategory.salary:        return 'Salary';
      case TransactionCategory.freelance:     return 'Freelance';
      case TransactionCategory.investment:    return 'Investment';
      case TransactionCategory.gift:          return 'Gift';
      case TransactionCategory.other:         return 'Other';
    }
  }

  static List<TransactionCategory> forType(TransactionType type) {
    if (type == TransactionType.income) {
      return const [
        TransactionCategory.salary,
        TransactionCategory.freelance,
        TransactionCategory.investment,
        TransactionCategory.gift,
        TransactionCategory.other,
      ];
    }
    return const [
      TransactionCategory.food,
      TransactionCategory.transport,
      TransactionCategory.shopping,
      TransactionCategory.health,
      TransactionCategory.entertainment,
      TransactionCategory.housing,
      TransactionCategory.education,
      TransactionCategory.utilities,
      TransactionCategory.other,
    ];
  }
}
