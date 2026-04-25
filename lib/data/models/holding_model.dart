import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/holding.dart';
import '../../domain/entities/holding_type.dart';

class HoldingModel {
  const HoldingModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.ticker,
    required this.type,
    required this.quantity,
    required this.avgCostPrice,
    required this.currentPrice,
    required this.currency,
    required this.accountId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String ticker;
  final HoldingType type;
  final double quantity;
  final double avgCostPrice;
  final double currentPrice;
  final String currency;
  final String? accountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory HoldingModel.fromEntity(Holding e) => HoldingModel(
        id: e.id,
        userId: e.userId,
        name: e.name,
        ticker: e.ticker,
        type: e.type,
        quantity: e.quantity,
        avgCostPrice: e.avgCostPrice,
        currentPrice: e.currentPrice,
        currency: e.currency,
        accountId: e.accountId,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  Holding toEntity() => Holding(
        id: id,
        userId: userId,
        name: name,
        ticker: ticker,
        type: type,
        quantity: quantity,
        avgCostPrice: avgCostPrice,
        currentPrice: currentPrice,
        currency: currency,
        accountId: accountId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'ticker': ticker,
        'type': type.name,
        'quantity': quantity,
        'avgCostPrice': avgCostPrice,
        'currentPrice': currentPrice,
        'currency': currency,
        'accountId': accountId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory HoldingModel.fromMap(Map<String, dynamic> map) => HoldingModel(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        ticker: map['ticker'] as String,
        type: HoldingType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => HoldingType.other,
        ),
        quantity: (map['quantity'] as num).toDouble(),
        avgCostPrice: (map['avgCostPrice'] as num).toDouble(),
        currentPrice: (map['currentPrice'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'USD',
        accountId: map['accountId'] as String?,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      );
}
