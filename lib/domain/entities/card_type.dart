enum CardType { credit, debit, prepaid }

extension CardTypeX on CardType {
  String get label {
    switch (this) {
      case CardType.credit:  return 'Credit';
      case CardType.debit:   return 'Debit';
      case CardType.prepaid: return 'Prepaid';
    }
  }
}
