import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/account_type.dart';

class AccountModel {
  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    required this.initialBalance,
    required this.currency,
    required this.linkedCashAccountId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final double balance;
  final double initialBalance;
  final String currency;
  final String? linkedCashAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AccountModel.fromEntity(Account e) => AccountModel(
        id: e.id,
        userId: e.userId,
        name: e.name,
        type: e.type,
        balance: e.balance,
        initialBalance: e.initialBalance,
        currency: e.currency,
        linkedCashAccountId: e.linkedCashAccountId,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  Account toEntity() => Account(
        id: id,
        userId: userId,
        name: name,
        type: type,
        balance: balance,
        initialBalance: initialBalance,
        currency: currency,
        linkedCashAccountId: linkedCashAccountId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'type': type.name,
        'balance': balance,
        'initialBalance': initialBalance,
        'currency': currency,
        'linkedCashAccountId': linkedCashAccountId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        type: AccountType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => AccountType.other,
        ),
        balance: (map['balance'] as num).toDouble(),
        initialBalance: (map['initialBalance'] as num?)?.toDouble() ?? 0,
        currency: map['currency'] as String? ?? 'KRW',
        linkedCashAccountId: map['linkedCashAccountId'] as String?,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      );
}
