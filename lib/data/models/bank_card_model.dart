import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/bank_card.dart';
import '../../domain/entities/card_network.dart';
import '../../domain/entities/card_type.dart';

class BankCardModel {
  const BankCardModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.last4Digits,
    required this.type,
    required this.network,
    required this.balance,
    required this.creditLimit,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String last4Digits;
  final CardType type;
  final CardNetwork network;
  final double balance;
  final double? creditLimit;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BankCardModel.fromEntity(BankCard e) => BankCardModel(
        id: e.id,
        userId: e.userId,
        name: e.name,
        last4Digits: e.last4Digits,
        type: e.type,
        network: e.network,
        balance: e.balance,
        creditLimit: e.creditLimit,
        currency: e.currency,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  BankCard toEntity() => BankCard(
        id: id,
        userId: userId,
        name: name,
        last4Digits: last4Digits,
        type: type,
        network: network,
        balance: balance,
        creditLimit: creditLimit,
        currency: currency,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'last4Digits': last4Digits,
        'type': type.name,
        'network': network.name,
        'balance': balance,
        'creditLimit': creditLimit,
        'currency': currency,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory BankCardModel.fromMap(Map<String, dynamic> map) => BankCardModel(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        last4Digits: map['last4Digits'] as String,
        type: CardType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => CardType.debit,
        ),
        network: CardNetwork.values.firstWhere(
          (e) => e.name == map['network'],
          orElse: () => CardNetwork.other,
        ),
        balance: (map['balance'] as num).toDouble(),
        creditLimit: (map['creditLimit'] as num?)?.toDouble(),
        currency: map['currency'] as String? ?? 'KRW',
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      );
}
