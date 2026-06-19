import 'package:flutter/material.dart';

import '../../domain/entities/transaction_category.dart';

extension TransactionCategoryUi on TransactionCategory {
  IconData get icon {
    switch (this) {
      case TransactionCategory.food:          return Icons.restaurant_rounded;
      case TransactionCategory.transport:     return Icons.directions_car_rounded;
      case TransactionCategory.shopping:      return Icons.shopping_bag_rounded;
      case TransactionCategory.health:        return Icons.favorite_rounded;
      case TransactionCategory.entertainment: return Icons.movie_rounded;
      case TransactionCategory.housing:       return Icons.home_rounded;
      case TransactionCategory.education:     return Icons.school_rounded;
      case TransactionCategory.utilities:     return Icons.bolt_rounded;
      case TransactionCategory.investment:    return Icons.show_chart_rounded;
      case TransactionCategory.other:         return Icons.more_horiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TransactionCategory.food:          return const Color(0xFFF97316);
      case TransactionCategory.transport:     return const Color(0xFF3B82F6);
      case TransactionCategory.shopping:      return const Color(0xFFEC4899);
      case TransactionCategory.health:        return const Color(0xFFEF4444);
      case TransactionCategory.entertainment: return const Color(0xFF8B5CF6);
      case TransactionCategory.housing:       return const Color(0xFF10B981);
      case TransactionCategory.education:     return const Color(0xFF06B6D4);
      case TransactionCategory.utilities:     return const Color(0xFFF59E0B);
      case TransactionCategory.investment:    return const Color(0xFF6366F1);
      case TransactionCategory.other:         return const Color(0xFF94A3B8);
    }
  }
}

/// All categories available when adding a Purchase row.
const List<TransactionCategory> purchaseCategories = TransactionCategory.values;
