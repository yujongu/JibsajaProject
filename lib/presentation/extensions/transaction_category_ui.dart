import 'package:flutter/material.dart';

import '../../domain/entities/transaction_category.dart';

extension TransactionCategoryUi on TransactionCategory {
  IconData get icon {
    switch (this) {
      case TransactionCategory.monthly:     return Icons.event_repeat_rounded;
      case TransactionCategory.transport:   return Icons.directions_car_rounded;
      case TransactionCategory.food:        return Icons.restaurant_rounded;
      case TransactionCategory.necessities: return Icons.shopping_basket_rounded;
      case TransactionCategory.clothing:    return Icons.checkroom_rounded;
      case TransactionCategory.fun:         return Icons.celebration_rounded;
      case TransactionCategory.delivery:    return Icons.delivery_dining_rounded;
      case TransactionCategory.misc:        return Icons.more_horiz_rounded;
      case TransactionCategory.work:        return Icons.work_rounded;
      case TransactionCategory.event:       return Icons.card_giftcard_rounded;
      case TransactionCategory.wedding:     return Icons.favorite_rounded;
      case TransactionCategory.travel:      return Icons.flight_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TransactionCategory.monthly:     return const Color(0xFF6366F1);
      case TransactionCategory.transport:   return const Color(0xFF3B82F6);
      case TransactionCategory.food:        return const Color(0xFFF97316);
      case TransactionCategory.necessities: return const Color(0xFF10B981);
      case TransactionCategory.clothing:    return const Color(0xFFEC4899);
      case TransactionCategory.fun:         return const Color(0xFF8B5CF6);
      case TransactionCategory.delivery:    return const Color(0xFFF59E0B);
      case TransactionCategory.misc:        return const Color(0xFF94A3B8);
      case TransactionCategory.work:        return const Color(0xFF06B6D4);
      case TransactionCategory.event:       return const Color(0xFFEF4444);
      case TransactionCategory.wedding:     return const Color(0xFFF43F5E);
      case TransactionCategory.travel:      return const Color(0xFF14B8A6);
    }
  }
}

/// All categories available when adding a Purchase row.
const List<TransactionCategory> purchaseCategories = TransactionCategory.values;
