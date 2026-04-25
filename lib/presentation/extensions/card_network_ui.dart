import 'package:flutter/material.dart';

import '../../domain/entities/card_network.dart';

extension CardNetworkUi on CardNetwork {
  IconData get icon {
    switch (this) {
      case CardNetwork.visa:
      case CardNetwork.mastercard:
      case CardNetwork.amex:
      case CardNetwork.local:
      case CardNetwork.other:
        return Icons.credit_card_rounded;
    }
  }
}
