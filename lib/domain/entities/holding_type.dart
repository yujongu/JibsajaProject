enum HoldingType { stock, etf, crypto, bond, other }

extension HoldingTypeX on HoldingType {
  String get label {
    switch (this) {
      case HoldingType.stock:  return 'Stock';
      case HoldingType.etf:    return 'ETF';
      case HoldingType.crypto: return 'Crypto';
      case HoldingType.bond:   return 'Bond';
      case HoldingType.other:  return 'Other';
    }
  }
}
