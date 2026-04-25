enum AccountType { checking, savings, investment, cash, other }

extension AccountTypeX on AccountType {
  String get label {
    switch (this) {
      case AccountType.checking:   return 'Checking';
      case AccountType.savings:    return 'Savings';
      case AccountType.investment: return 'Investment';
      case AccountType.cash:       return 'Cash';
      case AccountType.other:      return 'Other';
    }
  }

  bool get isLiquid => this != AccountType.investment;
}
