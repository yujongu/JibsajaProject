import 'card_network.dart';
import 'card_type.dart';

/// Named BankCard to avoid conflict with Flutter's Card widget.
class BankCard {
  const BankCard({
    required this.id,
    required this.userId,
    required this.name,
    required this.last4Digits,
    required this.type,
    required this.network,
    required this.balance,
    this.creditLimit,
    this.currency = 'KRW',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String last4Digits;
  final CardType type;
  final CardNetwork network;

  /// For credit cards: current statement balance (amount owed).
  /// For debit/prepaid: current available balance.
  final double balance;

  /// Credit limit (only applicable for credit cards).
  final double? creditLimit;

  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  double? get availableCredit =>
      creditLimit != null ? creditLimit! - balance : null;

  BankCard copyWith({
    String? name,
    String? last4Digits,
    CardType? type,
    CardNetwork? network,
    double? balance,
    double? creditLimit,
    String? currency,
  }) {
    return BankCard(
      id: id,
      userId: userId,
      name: name ?? this.name,
      last4Digits: last4Digits ?? this.last4Digits,
      type: type ?? this.type,
      network: network ?? this.network,
      balance: balance ?? this.balance,
      creditLimit: creditLimit ?? this.creditLimit,
      currency: currency ?? this.currency,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
