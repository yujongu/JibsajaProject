import 'asset_type.dart';
import 'transaction_category.dart';
import 'transaction_type.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.userId,
    this.accountId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note,
    this.currency = 'KRW',
    this.isDebit,
    this.ticker,
    this.assetName,
    this.assetType,
    this.quantity,
    this.pricePerUnit,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? accountId;
  final String title;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime date;
  final String? note;
  final String currency;

  /// For transfer transactions: true = money out (debit), false = money in (credit).
  final bool? isDebit;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated only for buy/sell transactions
  final String? ticker;
  final String? assetName;
  final AssetType? assetType;
  final double? quantity;
  final double? pricePerUnit;

  Transaction copyWith({
    String? accountId,
    String? title,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    DateTime? date,
    String? note,
    String? currency,
    bool? isDebit,
    String? ticker,
    String? assetName,
    AssetType? assetType,
    double? quantity,
    double? pricePerUnit,
  }) {
    return Transaction(
      id: id,
      userId: userId,
      accountId: accountId ?? this.accountId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      currency: currency ?? this.currency,
      isDebit: isDebit ?? this.isDebit,
      ticker: ticker ?? this.ticker,
      assetName: assetName ?? this.assetName,
      assetType: assetType ?? this.assetType,
      quantity: quantity ?? this.quantity,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
