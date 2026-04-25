import 'package:flutter/material.dart';

import '../../domain/entities/holding_type.dart';

extension HoldingTypeUi on HoldingType {
  IconData get icon {
    switch (this) {
      case HoldingType.stock:  return Icons.show_chart_rounded;
      case HoldingType.etf:    return Icons.pie_chart_rounded;
      case HoldingType.crypto: return Icons.currency_bitcoin_rounded;
      case HoldingType.bond:   return Icons.account_balance_rounded;
      case HoldingType.other:  return Icons.trending_up_rounded;
    }
  }

  Color get color {
    switch (this) {
      case HoldingType.stock:  return const Color(0xFF60A5FA);
      case HoldingType.etf:    return const Color(0xFF34D399);
      case HoldingType.crypto: return const Color(0xFFF59E0B);
      case HoldingType.bond:   return const Color(0xFFA78BFA);
      case HoldingType.other:  return const Color(0xFF94A3B8);
    }
  }
}
