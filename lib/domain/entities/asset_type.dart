enum AssetType { stock, etf, crypto, bond, other }

extension AssetTypeX on AssetType {
  String get label {
    switch (this) {
      case AssetType.stock:  return 'Stock';
      case AssetType.etf:    return 'ETF';
      case AssetType.crypto: return 'Crypto';
      case AssetType.bond:   return 'Bond';
      case AssetType.other:  return 'Other';
    }
  }
}
