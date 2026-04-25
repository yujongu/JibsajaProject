enum CardNetwork { visa, mastercard, amex, local, other }

extension CardNetworkX on CardNetwork {
  String get label {
    switch (this) {
      case CardNetwork.visa:       return 'Visa';
      case CardNetwork.mastercard: return 'Mastercard';
      case CardNetwork.amex:       return 'Amex';
      case CardNetwork.local:      return 'Local';
      case CardNetwork.other:      return 'Other';
    }
  }
}
