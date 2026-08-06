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

  /// One hue per category, spread across the wheel so no two are confusable.
  /// The dark value is the lighter of the pair — it sits on the navy card.
  Color color(bool isDark) {
    switch (this) {
      case TransactionCategory.monthly: // indigo
        return isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
      case TransactionCategory.transport: // sky
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      case TransactionCategory.food: // orange
        return isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
      case TransactionCategory.necessities: // green
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case TransactionCategory.clothing: // pink
        return isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
      case TransactionCategory.fun: // violet
        return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      case TransactionCategory.delivery: // yellow
        return isDark ? const Color(0xFFFACC15) : const Color(0xFFCA8A04);
      case TransactionCategory.misc: // slate
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      case TransactionCategory.work: // lime
        return isDark ? const Color(0xFFA3E635) : const Color(0xFF65A30D);
      case TransactionCategory.event: // red
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case TransactionCategory.wedding: // fuchsia
        return isDark ? const Color(0xFFE879F9) : const Color(0xFFC026D3);
      case TransactionCategory.travel: // teal
        return isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    }
  }
}

/// All categories available when adding a Purchase row.
const List<TransactionCategory> purchaseCategories = TransactionCategory.values;
