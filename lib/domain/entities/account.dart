import 'account_type.dart';

class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.initialBalance = 0,
    this.currency = 'KRW',
    this.linkedCashAccountId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;

  /// Stored balance — used only for investment accounts (and as fallback).
  final double balance;

  /// Starting balance before any tracked transactions.
  /// For liquid accounts, current balance = initialBalance + income - expenses + transfers.
  final double initialBalance;

  final String currency;
  final String? linkedCashAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account copyWith({
    String? name,
    AccountType? type,
    double? balance,
    double? initialBalance,
    String? currency,
    String? linkedCashAccountId,
    bool clearLinkedCashAccount = false,
  }) {
    return Account(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      initialBalance: initialBalance ?? this.initialBalance,
      currency: currency ?? this.currency,
      linkedCashAccountId: clearLinkedCashAccount
          ? null
          : (linkedCashAccountId ?? this.linkedCashAccountId),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
