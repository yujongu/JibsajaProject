import 'package:flutter/material.dart';

import '../../domain/entities/account_type.dart';

extension AccountTypeUi on AccountType {
  IconData get icon {
    switch (this) {
      case AccountType.checking:   return Icons.account_balance_rounded;
      case AccountType.savings:    return Icons.savings_rounded;
      case AccountType.investment: return Icons.show_chart_rounded;
      case AccountType.cash:       return Icons.payments_rounded;
      case AccountType.other:      return Icons.account_balance_wallet_rounded;
    }
  }
}
