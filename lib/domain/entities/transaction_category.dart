/// Expense categories, mirroring the sheet's Category column values exactly
/// (mixed English/Korean — see [TransactionCategoryX.sheetValue]).
enum TransactionCategory {
  monthly,     // Monthly (recurring bills)
  transport,   // 교통
  food,        // 식비
  necessities, // 생필품
  clothing,    // 의류
  fun,         // Fun
  delivery,    // 배달음식
  misc,        // Misc.
  work,        // Work
  event,       // 경조사
  wedding,     // 웨딩
  travel,      // 여행
}

extension TransactionCategoryX on TransactionCategory {
  /// Wire value written to the sheet's `Category` column. Also used as the
  /// display label so the app always shows exactly what the sheet stores.
  String get sheetValue {
    switch (this) {
      case TransactionCategory.monthly:     return 'Monthly';
      case TransactionCategory.transport:   return '교통';
      case TransactionCategory.food:        return '식비';
      case TransactionCategory.necessities: return '생필품';
      case TransactionCategory.clothing:    return '의류';
      case TransactionCategory.fun:         return 'Fun';
      case TransactionCategory.delivery:    return '배달음식';
      case TransactionCategory.misc:        return 'Misc.';
      case TransactionCategory.work:        return 'Work';
      case TransactionCategory.event:       return '경조사';
      case TransactionCategory.wedding:     return '웨딩';
      case TransactionCategory.travel:      return '여행';
    }
  }

  String get label => sheetValue;

  /// Parse the sheet's `Category` column back into an enum. Matches the wire
  /// value (case-insensitively) or the Dart enum name (legacy rows written by
  /// early app versions). Unknown values fall back to [misc].
  static TransactionCategory fromSheet(String? raw) {
    final v = raw?.trim().toLowerCase();
    if (v == null || v.isEmpty) return TransactionCategory.misc;
    return TransactionCategory.values.firstWhere(
      (c) => c.sheetValue.toLowerCase() == v || c.name == v,
      orElse: () => TransactionCategory.misc,
    );
  }
}
