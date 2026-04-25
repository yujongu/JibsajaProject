import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../domain/entities/asset_type.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/entities/transaction_type.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.note,
    required this.currency,
    required this.isDebit,
    required this.ticker,
    required this.assetName,
    required this.assetType,
    required this.quantity,
    required this.pricePerUnit,
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
  final bool? isDebit;
  final String? ticker;
  final String? assetName;
  final AssetType? assetType;
  final double? quantity;
  final double? pricePerUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TransactionModel.fromEntity(Transaction e) => TransactionModel(
        id: e.id,
        userId: e.userId,
        accountId: e.accountId,
        title: e.title,
        amount: e.amount,
        type: e.type,
        category: e.category,
        date: e.date,
        note: e.note,
        currency: e.currency,
        isDebit: e.isDebit,
        ticker: e.ticker,
        assetName: e.assetName,
        assetType: e.assetType,
        quantity: e.quantity,
        pricePerUnit: e.pricePerUnit,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  Transaction toEntity() => Transaction(
        id: id,
        userId: userId,
        accountId: accountId,
        title: title,
        amount: amount,
        type: type,
        category: category,
        date: date,
        note: note,
        currency: currency,
        isDebit: isDebit,
        ticker: ticker,
        assetName: assetName,
        assetType: assetType,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'accountId': accountId,
        'title': title,
        'amount': amount,
        'type': type.name,
        'category': category.name,
        'date': Timestamp.fromDate(date),
        'note': note,
        'currency': currency,
        'isDebit': isDebit,
        'ticker': ticker,
        'assetName': assetName,
        'assetType': assetType?.name,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final assetTypeStr = map['assetType'] as String?;
    return TransactionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      accountId: map['accountId'] as String?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'expense'),
        orElse: () => TransactionType.expense,
      ),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == (map['category'] as String? ?? 'other'),
        orElse: () => TransactionCategory.other,
      ),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'] as String?,
      currency: map['currency'] as String? ?? 'KRW',
      isDebit: map['isDebit'] as bool?,
      ticker: map['ticker'] as String?,
      assetName: map['assetName'] as String?,
      assetType: assetTypeStr == null
          ? null
          : AssetType.values.firstWhere(
              (e) => e.name == assetTypeStr,
              orElse: () => AssetType.stock,
            ),
      quantity: (map['quantity'] as num?)?.toDouble(),
      pricePerUnit: (map['pricePerUnit'] as num?)?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
